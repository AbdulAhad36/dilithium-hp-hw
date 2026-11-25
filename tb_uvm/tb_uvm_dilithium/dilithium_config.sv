  class dilithium_config extends uvm_object;
    `uvm_object_utils(dilithium_config)
    dilithium_transaction cases[$];string token,directory,prefix;
    uvm_active_passive_enum is_active=UVM_ACTIVE;
    function new(string name="dilithium_config");super.new(name);endfunction
    function void load();
      int f,n,rc;string t;dilithium_transaction c;
      if(!$value$plusargs("DILITHIUM_DIR=%s",directory))directory=".";
      if(!$value$plusargs("DILITHIUM_PREFIX=%s",prefix))prefix={directory,"/uvm"};
      f=$fopen({directory,"/uvm_inputs.txt"},"r");
      if(!f || $fscanf(f,"%s %d",token,n)!=2)`uvm_fatal("FIXTURE","Run Python uvm_prepare")
      repeat(n)begin
        c=dilithium_transaction::type_id::create($sformatf("case_%0d",cases.size()));rc=$fscanf(f,"%d %d %d %d %d %d %d %d %d %h %h %s %s %s",c.serial,c.op,c.p,c.id,c.ctx,c.mlen,c.siglen,c.profile,c.abort_cycles,c.seed,c.rnd,c.first,c.second,c.body);
        if(rc!=14 || c.serial!=cases.size())`uvm_fatal("FIXTURE","Malformed input row")
        cases.push_back(c);
      end
      if($fscanf(f,"%s",t)==1)`uvm_fatal("FIXTURE","Trailing input row")
      $fclose(f);
    endfunction
  endclass
