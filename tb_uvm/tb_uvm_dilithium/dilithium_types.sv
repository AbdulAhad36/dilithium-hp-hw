// Package-local event types and fixture byte helpers.
  typedef enum {START,INPUT_SIGN,INPUT_VERIFY,KEY_WORD,SIG_WORD,DONE,RESET,RETIRED} event_e;
  function automatic byte unsigned octet(string s,int i);
    bit [7:0] v;
    if(s=="-" || i<0 || 2*i+1>=s.len())return 0;
    if($sscanf(s.substr(2*i,2*i+1),"%h",v)!=1)$fatal(1,"Invalid hex fixture");
    return v;
  endfunction
  function automatic int size_bytes(string s);return s=="-"?0:s.len()/2;endfunction


