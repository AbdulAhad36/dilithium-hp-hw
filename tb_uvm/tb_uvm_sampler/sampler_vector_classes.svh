// Included inside sampler_uvm_pkg, after the common environment/classes.
// The capture subscriber writes observations only; it never reads expected.txt.
class sampler_vector_seq extends sampler_smoke_seq;
  `uvm_object_utils(sampler_vector_seq)
  int expected_jobs,expected_success,expected_errors,expected_aborts;
  function new(string name="sampler_vector_seq");super.new(name);endfunction
  task body();
    string path="../FIPS204_SAMPLER/sampler_inputs.txt";
    string token,run_id;
    int fd,rc,core,id,mode,param,nbytes,last,commands=0;
    bit [127:0] data;
    bit ended=0;
    void'($value$plusargs("SAMPLER_VECTOR_FILE=%s",path));
    fd=$fopen(path,"r");
    if(fd==0)`uvm_fatal("VECTOR_FILE",$sformatf("Cannot read %s; run Python prepare first",path))
    rc=$fscanf(fd,"%s %s %d %d %d %d",token,run_id,expected_jobs,
                expected_success,expected_errors,expected_aborts);
    if(rc!=6 || token!="H" || run_id.len()!=32 || expected_jobs<=0 ||
       expected_jobs!=expected_success+expected_errors+expected_aborts)
      `uvm_fatal("VECTOR_FILE","Invalid vector header")
    while(!ended)begin
      rc=$fscanf(fd,"%s",token);
      if(rc!=1)`uvm_fatal("VECTOR_FILE","Input truncated before E record")
      case(token)
        "J":begin
          rc=$fscanf(fd,"%d %d %d %d",core,id,mode,param);
          if(rc!=4 || core<0 || core>1 || id<0 || id>65535 ||
             mode<0 || mode>3 || param<0 || param>3)
            `uvm_fatal("VECTOR_FILE","Invalid J record")
          command(EV_JOB,core,id,mode,param);commands++;
        end
        "B":begin
          rc=$fscanf(fd,"%d %d %d %h",core,nbytes,last,data);
          if(rc!=4 || core<0 || core>1 || nbytes<0 || nbytes>31 || last<0 || last>1)
            `uvm_fatal("VECTOR_FILE","Invalid B record")
          beat(core,data,nbytes,1'(last),commands%5==0 ? 2:0);
        end
        "R":command(EV_RESET);
        "W":command(EV_WAIT);
        "E":ended=1;
        default:`uvm_fatal("VECTOR_FILE",$sformatf("Unknown input command %s",token))
      endcase
    end
    rc=$fscanf(fd,"%s",token);
    if(rc==1 || commands!=expected_jobs)`uvm_fatal("VECTOR_FILE","Extra records or descriptor count mismatch")
    $fclose(fd);
    command(EV_WAIT);
  endtask
endclass

class sampler_capture extends uvm_subscriber#(sampler_item);
  `uvm_component_utils(sampler_capture)
  int fd,jobs,success,errors,aborted,coefficients;
  int count[2],received[2],ids[2];
  bit live[2];
  bit enabled=1;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  function void build_phase(uvm_phase phase);
    string input_path="../FIPS204_SAMPLER/sampler_inputs.txt";
    string output_path="sampler/sampler_dut_outputs.txt";
    string token,run_id;
    int source,rc;
    void'($value$plusargs("SAMPLER_VECTOR_FILE=%s",input_path));
    void'($value$plusargs("SAMPLER_OUTPUT_FILE=%s",output_path));
    source=$fopen(input_path,"r");
    if(source==0)`uvm_fatal("CAPTURE","Input file missing")
    rc=$fscanf(source,"%s %s",token,run_id);$fclose(source);
    if(rc!=2 || token!="H" || run_id.len()!=32)`uvm_fatal("CAPTURE","Invalid manifest header")
    fd=$fopen(output_path,"w");
    if(fd==0)`uvm_fatal("CAPTURE","Cannot create DUT output file")
    $fdisplay(fd,"H %s",run_id);
  endfunction
  function void write(sampler_item t);
    int c=t.core;
    if(!enabled)return;
    case(t.kind)
      EV_RESET:begin
        foreach(live[k])if(live[k])begin
          $fdisplay(fd,"A %0d %0d %0d %0d",k,ids[k],count[k],received[k]);
          aborted++;live[k]=0;
        end
      end
      EV_JOB:begin
        live[c]=1;ids[c]=t.id;count[c]=0;received[c]=0;jobs++;
        $fdisplay(fd,"J %0d %0d %0d %0d",c,t.id,t.mode,t.param);
      end
      EV_INPUT:if(t.nbytes>=1 && t.nbytes<=16)received[c]+=t.nbytes;
      EV_OUTPUT:begin
        $fdisplay(fd,"C %0d %0d %0d %0d %0d",c,t.id,t.index,t.value,t.last);
        count[c]++;coefficients++;
      end
      EV_STATUS:begin
        $fdisplay(fd,"S %0d %0d %0d %0d %0d",c,t.id,t.code,count[c],received[c]);
        if(t.code==0)success++;else errors++;
        live[c]=0;$fflush(fd);
      end
      default:;
    endcase
  endfunction
  function void report_phase(uvm_phase phase);
    if(uvm_report_server::get_server().get_severity_count(UVM_ERROR)==0 &&
       uvm_report_server::get_server().get_severity_count(UVM_FATAL)==0)begin
      $fdisplay(fd,"F %0d %0d %0d %0d %0d",jobs,success,errors,aborted,coefficients);
    end
    $fclose(fd);
  endfunction
endclass

class sampler_vector_test extends uvm_test;
  `uvm_component_utils(sampler_vector_test)
  sampler_env env;
  sampler_capture capture;
  sampler_vector_seq seq;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  function void build_phase(uvm_phase phase);
    env=sampler_env::type_id::create("env",this);
    capture=sampler_capture::type_id::create("capture",this);
  endfunction
  function void connect_phase(uvm_phase phase);env.monitor.ap.connect(capture.analysis_export);endfunction
  task run_phase(uvm_phase phase);
    seq=sampler_vector_seq::type_id::create("seq");
    phase.raise_objection(this);seq.start(env.sequencer);#100ns;phase.drop_objection(this);
  endtask
  function void check_phase(uvm_phase phase);
    if(env.scoreboard.passed!=seq.expected_success || env.scoreboard.failed_jobs!=seq.expected_errors ||
       env.scoreboard.aborted!=seq.expected_aborts || capture.jobs!=seq.expected_jobs ||
       env.scoreboard.live[0] || env.scoreboard.live[1] ||
       uvm_report_server::get_server().get_severity_count(UVM_ERROR)!=0)
      `uvm_fatal("VECTOR_GATE","Incomplete capture or unexpected UVM result")
    `uvm_info("CAPTURE",$sformatf("SAMPLER VECTOR CAPTURE COMPLETE: %0d jobs, %0d coefficients; run Python compare separately",capture.jobs,capture.coefficients),UVM_NONE)
  endfunction
  function void report_phase(uvm_phase phase);
    `uvm_info("COVERAGE",$sformatf("Vector checked-polynomial group: %0.2f%%;12-group summary follows; separate database, not full functional coverage",env.coverage.checked_polynomial.get_inst_coverage()),UVM_NONE)
  endfunction
endclass
