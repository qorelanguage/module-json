#!/usr/bin/env qore

# a generic JSON-RPC client
# usage: json-rpc-client.q [-uURL] method [parameters]

# disable the use of global variables
%no-global-vars
# execute the application class
%exec-class json_rpc_client

%requires json

# define command-line options for GetOpt class
const json_rpc_opts = 
    ( "url"  : "url,u=s",
      "json"  : "json,x",
      "verb" : "verbose,v",
      "help" : "help,h" );

# define our application class
class json_rpc_client {
    private $.o;

    constructor() {
	$.process_command_line();
	if (!elements $ARGV)
	    $.usage();

	if (!exists $.o.url)
	    $.o.url = "http://localhost:8081";
    
	#printf("sending command to \"%s\"\n", $s);

	my $cmd = shift $ARGV;

	my $rs;
	my hash $callinfo;
	try {
	    my $xrc = new JsonRpcClient(( "url" : $.o.url ));
	    my $args;
	    foreach my $arg in ($ARGV)
		# in case make_option() returns a list
		$args[elements $args] = $.make_option($arg);
	    
	    #printf("%s", dbg_node_info($args));
	    $rs = $xrc.callArgsWithInfo(\$callinfo, $cmd, $args);

	    if ($.o.verb) {
		if ($.o.json)
		    printf("outgoing message:\n%s\n", $callinfo.request);
		else
		    printf("args=%N\n", $args);
	    }

	}
	catch ($ex) {
	    printf("%s: %s\n", $ex.err, $ex.desc);
	    exit(1);
	}
	if ($.o.json) {
	    printf("response:\n%s\n", $callinfo.response);
	    return;
	}
    
	if (exists $rs.error) {
	    printf("ERROR: %s\n", $rs.error.message);
	    exit(1);
	}
	my $info = $rs.result;
	
	if (exists $info) {
	    if (type($info) == Type::String)
		print($info);
	    else
		printf("%N", $info);
	    if (type($info) != String || substr($info, -1) != "\n")
		print("\n");
	}
	else
	    print("OK\n");
    }

    private usage() {
	printf(
"usage: %s [options] <command> [parameters...]
  -u,--url=arg       sets JSON-RPC command url (ex: jsonrpc://host:port)
  -x,--json          shows literal json response
  -v,--verbose       shows more information
  -h,--help          this help text
", basename($ENV."_"));
	exit(1);
    }

    private process_command_line() {
	my $g = new GetOpt(json_rpc_opts);
	$.o = $g.parse(\$ARGV);
	if (exists $.o{"_ERRORS_"}) {
	    printf("%s\n", $.o{"_ERRORS_"}[0]);
	    exit(1);
	}
	if ($.o.help)
	    $.usage();
    }

    private make_option($arg) {
	if (!strlen($arg))
	    return;

	# see if it's an int
	if (int($arg) == $arg) {
	    if (int($arg) >= 2147483648)
		return $arg;
	    return int($arg);
	}
	
	# see if it's an object or list
	my $str  = sprintf("sub get() { return %s; }", $arg);
	#printf("%s\n", $str);
	my $prog = new Program();
	try {
	    $prog.parse($str, "main");
	    my $rv = $prog.callFunction("get");
	    #printf("no exception, rv=%s (%n)\nstr=%s\n", $rv, $rv, $str);
	    # if it's a float, then return a string to preseve formatting
	    if (type($rv) == Type::Float || !exists $rv)
		return $arg;
	    return $rv;
	}

	catch ($ex) {
	    #printf("exception %s\n", $ex.err);
	    # must be a string
	    # see if it's a string like "key=val"
	    if ((my $i = index($arg, "=")) != -1) {
		my $h{substr($arg, 0, $i)} = substr($arg, $i + 1);
		return $h;
	    }
	    return $arg;
	}
    }
}
