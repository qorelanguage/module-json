#!/usr/bin/env qore 
# -*- mode: qore; indent-tabs-mode: nil -*-

# require all global variables to be declared with "our"
%require-our
# enable all warnings
%enable-all-warnings
# child programs do not inherit parent's restrictions
%no-child-restrictions
# require types to be declared
%require-types

# make sure we have the right version of qore
%requires qore >= 0.8.1

# make sure we have the json module
%requires json

our (hash $o, int $errors);
our hash $thash;

sub usage() {
    printf(
"usage: %s [options] <iterations>
  -h,--help         shows this help text
  -t,--threads=ARG  runs tests in ARG threads
  -v,--verbose=ARG  sets verbosity level to ARG
", 
        get_script_name());
    exit(1);
}

const opts = 
    ( "verbose" : "verbose,v:i+",
      "help"    : "help,h",
      "threads" : "threads,t=i" );

sub parse_command_line() {
    my GetOpt $g = new GetOpt(opts);
    $o = $g.parse(\$ARGV);
    if (exists $o."_ERRORS_") {
        printf("%s\n", $o."_ERRORS_"[0]);
        exit(1);
    }
    if ($o.help)
	usage();

    $o.iters = shift $ARGV;
    if (elements $ARGV) {
	printf("error, excess arguments on command-line\n");
	usage();
    }

    if (!$o.iters)
	$o.iters = 1;
    if (!$o.threads)
	$o.threads = 1;
}

sub test_value(any $v1, any $v2, string $msg) {
    if ($v1 === $v2) {
	if ($o.verbose)
	    printf("OK: %s test\n", $msg);
    }
    else {
	printf("ERROR: %s test failed! (%N != %N)\n", $msg, $v1, $v2);
	#printf("%s%s", dbg_node_info($v1), dbg_node_info($v2));
	$errors++;
    }
    $thash.$msg = True;
}

sub json_tests() {
    my hash $h = ( "test" : 1, 
		   "gee" : "philly-\"test-quotes\"", 
		   "marguile" : 1.0392,
		   "list" : (1, 2, 3, ( "four" : 4 ), 5.0, True, ( "key1" : "one", "key2" : 2.0 )),
		   "hash" : ( "howdy" : 123, "partner" : 456 ),
		   "bool" : True,
		   "time" : format_date("YYYY-MM-DD HH:mm:SS", now()),
		   "key"  : "this & that",
                   "newline" : "lorem ipsum\ndolor\tsir amet",
                 );

    my string $jstr = makeJSONString($h);
    test_value($h == parseJSON($jstr), True, "first JSON");

    my string $ver = "1.1";
    my int $id = 512;
    my string $method = "methodname";
    my string $mess = "an error occurred, OH NO!!!!";

    my hash $jc = ( "version" : $ver,
		    "id" : $id,
		    "method" : $method,
		    "params" : $h );

    test_value(parseJSON(makeJSONRPCRequestString($method, $ver, $id, $h)) == $jc, True, "makeJSONRPCRequestString");
    test_value(parseJSON(makeFormattedJSONRPCRequestString($method, $ver, $id, $h)) == $jc, True, "makeJSONRPCRequestString");

    # create result hash by modifying the call hash above: delete "method" and "params" keys and add "result" key
    my hash $jr = $jc - "method" - "params" + ( "result" : $h );
    test_value(parseJSON(makeJSONRPCResponseString($ver, $id, $h)) == $jr, True, "makeJSONRPCResponseString");
    test_value(parseJSON(makeFormattedJSONRPCResponseString($ver, $id, $h)) == $jr, True, "makeFormattedJSONRPCResponseString");

    # create error hash by modifying the result hash: delete "result" key and add "error" key
    my hash $je = $jr - "result" + ( "error" : $h );
    test_value(parseJSON(makeJSONRPCErrorString($ver, $id, $h)) == $je, True, "makeJSONRPCErrorString");
    test_value(parseJSON(makeFormattedJSONRPCErrorString($ver, $id, $h)) == $je, True, "makeFormattedJSONRPCErrorString");

    # create JSON-RPC 1.1 error string
    $je = $je + ( "error" : ( "name" : "JSONRPCError", "code" : $id, "message" : $mess, "error" : $h ) );
    test_value(parseJSON(makeJSONRPC11ErrorString($id, $mess, $id, $h)) == $je, True, "makeJSONRPCErrorString");
    test_value(parseJSON(makeFormattedJSONRPC11ErrorString($id, $mess, $id, $h)) == $je, True, "makeFormattedJSONRPCErrorString");
}

sub do_tests() {
    on_exit $counter.dec();
    try {
	for (my int $i = 0; $i < $o.iters; $i++) {
	    if ($o.verbose)
		printf("TID %d: iteration %d\n", gettid(), $i);
	    json_tests();
	}
    }
    catch () {
	++$errors;
	rethrow;	
    }
}

sub main() {
    parse_command_line();
    printf("QORE v%s JSON Module v%s Test Script (%d thread%s, %d iteration%s per thread)\n",
           Qore::VersionString, get_module_hash().json.version,
	   $o.threads, $o.threads == 1 ? "" : "s", $o.iters, $o.iters == 1 ? "" : "s");

    our Counter $counter = new Counter();
    while ($o.threads--) {
	$counter.inc();
	background do_tests();
    }

    $counter.waitForZero();

    my int $ntests = elements $thash;
    printf("%d error%s encountered in %d test%s.\n",
	   $errors, $errors == 1 ? "" : "s", 
	   $ntests, $ntests == 1 ? "" : "s");
}

main();
