// Coverage replays accepted bytes ONLY after the independent scoreboard has
// checked all256 indexed coefficients and successful status. It never drives
// stimulus or supplies expected values to the scoreboard.
class sampler_coverage extends uvm_subscriber#(sampler_item);
  `uvm_component_utils(sampler_coverage)
  int credited_jobs,fd,robust_fd;
  string prefix="sampler/smoke";
  covergroup checked_polynomial with function sample(int core,mode,param,count);
    option.per_instance=1;
    cp_core:coverpoint core {bins c[]={0,1};}
    cp_mode:coverpoint mode {bins m[]={0,1,2,3};}
    cp_param:coverpoint param {bins p[]={0,1,2};}
    cp_count:coverpoint count {bins complete={256};}
    cx_mode_core_param:cross cp_mode,cp_core,cp_param;
  endgroup
  covergroup input_format with function sample(int mode,size);
    option.per_instance=1;
    cp_mode:coverpoint mode {bins m[]={0,1,2,3};}
    cp_bytes:coverpoint size {bins valid_bytes[]={[1:16]};}
    cx_mode_bytes:cross cp_mode,cp_bytes;
  endgroup
  covergroup scheduling with function sample(int mode,paired,switched,reused,outstall,instop,statusstall);
    option.per_instance=1;
    cp_mode:coverpoint mode {bins m[]={0,1,2,3};}
    cp_paired:coverpoint paired {bins alone={0};bins peer={1};}
    cp_switched:coverpoint switched {bins no={0};bins yes={1};}
    cp_reused:coverpoint reused {bins fresh={0};bins reused_id={1};}
    cp_out_stall:coverpoint outstall {bins none={0};bins short_stall={[1:4]};bins medium_stall={[5:16]};bins long_stall={[17:$]};}
    cp_input_block:coverpoint instop {bins none={0};bins short_block={[1:4]};bins medium_block={[5:16]};bins long_block={[17:$]};}
    cp_status_stall:coverpoint statusstall {bins none={0};bins short_stall={[1:5]};bins medium_stall={[6:16]};bins long_stall={[17:$]};}
    cx_mode_peer:cross cp_mode,cp_paired;
    cx_mode_output_stall:cross cp_mode,cp_out_stall;
  endgroup
  covergroup mode_transitions with function sample(int prior_mode,next_mode);
    option.per_instance=1;
    cp_prior:coverpoint prior_mode {bins m[]={0,1,2,3};}
    cp_next:coverpoint next_mode {bins m[]={0,1,2,3};}
    cx_transition:cross cp_prior,cp_next;
  endgroup
  covergroup matrix_candidates with function sample(int raw,topbit,offset,accepted);
    option.per_instance=1;
    cp_boundary:coverpoint raw {
      bins zero={0};bins one={1};bins interior={[2:8380415]};
      bins q_minus_one={8380416};bins q={8380417};bins q_plus_one={8380418};bins high_reject={[8380419:8388607]};
    }
    cp_top:coverpoint topbit {bins b[]={0,1};}
    cp_offset:coverpoint offset {bins b[]={[0:7]};}
    cp_accepted:coverpoint accepted {bins no={0};bins yes={1};}
    cx_top_accept:cross cp_top,cp_accepted;
    cx_offset_accept:cross cp_offset,cp_accepted;
  endgroup
  covergroup secret_candidates with function sample(int eta4,nibble,lane,accepted);
    option.per_instance=1;
    cp_eta4:coverpoint eta4 {bins eta2={0};bins eta4={1};}
    cp_nibble:coverpoint nibble {bins n[]={[0:15]};}
    cp_lane:coverpoint lane {bins n[]={[0:15]};}
    cp_accepted:coverpoint accepted {bins no={0};bins yes={1};}
    cx_eta_nibble:cross cp_eta4,cp_nibble;
    cx_lane_accept:cross cp_lane,cp_accepted;
  endgroup
  covergroup secret_compaction with function sample(int accepted_mask,count);
    option.per_instance=1;
    cp_mask:coverpoint accepted_mask {bins none={0};bins all={65535};bins mixed={[1:65534]};}
    cp_count:coverpoint count {bins n[]={[0:16]};}
  endgroup
  covergroup mask_fields with function sample(int wide,field_class);
    option.per_instance=1;
    cp_wide:coverpoint wide {bins width18={0};bins width20={1};}
    cp_field:coverpoint field_class {bins zero={0};bins one={1};bins gamma_minus_one={2};bins gamma={3};bins gamma_plus_one={4};bins max_minus_one={5};bins max={6};bins lower={7};bins upper={8};}
    cx_width_field:cross cp_wide,cp_field;
  endgroup
  // Byte input makes only even carries reachable at18 bits and multiples of4
  // at20 bits (gcd with8). Odd/unreachable states are not invented as holes.
  covergroup mask18_alignment with function sample(int carry,nbytes);
    option.per_instance=1;
    cp_carry:coverpoint carry {bins b[]={0,2,4,6,8,10,12,14,16};}
    cp_bytes:coverpoint nbytes {bins b[]={[1:8]};}
    cx_carry_bytes:cross cp_carry,cp_bytes;
  endgroup
  covergroup mask20_alignment with function sample(int carry,nbytes);
    option.per_instance=1;
    cp_carry:coverpoint carry {bins b[]={0,4,8,12,16};}
    cp_bytes:coverpoint nbytes {bins b[]={[1:8]};}
    cx_carry_bytes:cross cp_carry,cp_bytes;
  endgroup
  covergroup challenge_decisions with function sample(int param,reject_candidate,self_index,repeated_nonzero);
    option.per_instance=1;
    cp_param:coverpoint param {bins p[]={0,1,2};}
    cp_reject:coverpoint reject_candidate {bins no={0};bins yes={1};}
    cp_self:coverpoint self_index {bins no={0};bins yes={1};}
    cp_repeat:coverpoint repeated_nonzero {bins no={0};bins yes={1};}
    cx_param_reject:cross cp_param,cp_reject;
    cx_param_self:cross cp_param,cp_self;
    cx_param_repeat:cross cp_param,cp_repeat;
  endgroup
  covergroup coefficient_shape with function sample(int mode,index,value_class);
    option.per_instance=1;
    cp_mode:coverpoint mode {bins m[]={0,1,2,3};}
    cp_index:coverpoint index {bins first={0};bins second={1};bins interior={[2:253]};bins penultimate={254};bins last={255};}
    cp_value:coverpoint value_class {bins zero={0};bins lower_half={1};bins upper_half={2};}
    cx_mode_value:cross cp_mode,cp_value;
    cx_mode_index:cross cp_mode,cp_index;
  endgroup
  // End-to-end stress dimensions. Every cross combination is attainable on
  // the existing interface; unbounded waits/native128 are not coverage bins.
  covergroup stream_context with function sample(int core,mode,param,size);
    option.per_instance=1;
    cp_core:coverpoint core {bins c[]={0,1};}
    cp_mode:coverpoint mode {bins m[]={[0:3]};}
    cp_param:coverpoint param {bins p[]={[0:2]};}
    cp_bytes:coverpoint size {bins n[]={[1:16]};}
    cx_context_format:cross cp_core,cp_mode,cp_param,cp_bytes;
  endgroup
  covergroup rejection_bursts with function sample(int core,mode,param,run_length);
    option.per_instance=1;
    cp_core:coverpoint core {bins c[]={0,1};}
    cp_mode:coverpoint mode {bins a={0};bins secret={1};bins ball={3};}
    cp_param:coverpoint param {bins p[]={[0:2]};}
    cp_run:coverpoint run_length {
      bins none={0};bins single={1};bins short_run={[2:7]};bins lane_span={[8:31]};
      bins medium_run={[32:127]};bins polynomial_span={[128:511]};
      bins long_run={[512:2047]};bins extended_run={[2048:$]};
    }
    cx_context_run:cross cp_core,cp_mode,cp_param,cp_run;
  endgroup
  covergroup backpressure_context with function sample(int core,mode,outstall,statusstall);
    option.per_instance=1;
    cp_core:coverpoint core {bins c[]={0,1};}
    cp_mode:coverpoint mode {bins m[]={[0:3]};}
    cp_output:coverpoint outstall {
      bins none={0};bins short_wait={[1:16]};bins medium_wait={[17:127]};
      bins long_wait={[128:1023]};bins extended_wait={[1024:$]};
    }
    cp_status:coverpoint statusstall {
      bins none={0};bins short_wait={[1:16]};bins medium_wait={[17:127]};
      bins long_wait={[128:1023]};bins extended_wait={[1024:$]};
    }
    cx_output_context:cross cp_core,cp_mode,cp_output;
    cx_status_context:cross cp_core,cp_mode,cp_status;
  endgroup
  function new(string n,uvm_component p);
    super.new(n,p);
    checked_polynomial=new;input_format=new;scheduling=new;mode_transitions=new;
    matrix_candidates=new;secret_candidates=new;secret_compaction=new;
    mask_fields=new;mask18_alignment=new;mask20_alignment=new;
    challenge_decisions=new;coefficient_shape=new;
    stream_context=new;rejection_bursts=new;backpressure_context=new;
  endfunction
  function void build_phase(uvm_phase phase);
    void'($value$plusargs("SAMPLER_COV_PREFIX=%s",prefix));
    fd=$fopen({prefix,"_checked_jobs.csv"},"w");
    if(!fd)`uvm_fatal("COV_FILE","Cannot create checked-job witness file")
    $fdisplay(fd,"id,core,mode,param,checked_coefficients,input_bytes,input_beats,paired,input_switched,reused_id,previous_success_mode,max_output_stall,max_input_block,max_status_stall");
    robust_fd=$fopen({prefix,"_checked_robustness.csv"},"w");
    if(!robust_fd)`uvm_fatal("COV_FILE","Cannot create checked robustness witnesses")
    $fdisplay(robust_fd,"id,core,mode,param,max_rejection_run,max_output_stall,max_status_stall,input_beats");
  endfunction
  function int mask_class(int field,gamma);
    if(field==0)return 0;if(field==1)return 1;
    if(field==gamma-1)return 2;if(field==gamma)return 3;if(field==gamma+1)return 4;
    if(field==2*gamma-2)return 5;if(field==2*gamma-1)return 6;
    return field<gamma ? 7:8;
  endfunction
  function void write(sampler_item t);
    int pos=0,accepted=0,raw,topbit,nib,accept_mask,count,n,base,field,width,gamma;
    int polynomial[256],i,j,sign_number;
    int reject_run=0,max_reject_run=0;
    bit reservoir[$],b;
    if(t.kind!=EV_STATUS || t.code!=0 || t.value!=256 || t.cov_values.size()!=256)
      `uvm_fatal("COV_GATE","Coverage requires checked successful complete polynomial")
    if(uvm_report_server::get_server().get_severity_count(UVM_ERROR)!=0 ||
       uvm_report_server::get_server().get_severity_count(UVM_FATAL)!=0)begin
      `uvm_info("COV_WITHHELD","Protocol/checker errors present; withholding coverage credit",UVM_NONE)
      return;
    end
    credited_jobs++;
    checked_polynomial.sample(t.core,t.mode,t.param,t.value);
    scheduling.sample(t.mode,t.cov_paired,t.cov_switched,t.cov_reused,t.cov_out_stall,t.cov_input_block,t.cov_status_stall);
    if(t.cov_prev_mode<4)mode_transitions.sample(t.cov_prev_mode,t.mode);
    foreach(t.cov_sizes[k])input_format.sample(t.mode,t.cov_sizes[k]);
    foreach(t.cov_sizes[k])stream_context.sample(t.core,t.mode,t.param,t.cov_sizes[k]);
    backpressure_context.sample(t.core,t.mode,t.cov_out_stall,t.cov_status_stall);
    foreach(t.cov_values[k])coefficient_shape.sample(t.mode,k,t.cov_values[k]==0 ? 0:(t.cov_values[k]<=4190208 ? 1:2));
    case(t.mode)
      0:while(accepted<256 && pos+2<t.cov_bytes.size())begin
        raw=int'(t.cov_bytes[pos])|(int'(t.cov_bytes[pos+1])<<8)|(int'(t.cov_bytes[pos+2])<<16);
        topbit=(raw>>23)&1;raw&=8388607;
        matrix_candidates.sample(raw,topbit,pos%8,raw<8380417);
        if(raw<8380417)begin
          rejection_bursts.sample(t.core,t.mode,t.param,reject_run);reject_run=0;
        end else begin reject_run++;if(reject_run>max_reject_run)max_reject_run=reject_run;end
        if(raw<8380417)accepted++;pos+=3;
      end
      1:foreach(t.cov_sizes[k])begin
        base=0;
        while(base<t.cov_sizes[k] && accepted<256)begin
          n=t.cov_sizes[k]-base;if(n>8)n=8;accept_mask=0;count=0;
          for(int z=0;z<2*n && accepted<256;z++)begin
            nib=(t.cov_bytes[pos+z/2]>>(4*(z%2)))&15;
            secret_candidates.sample(t.param==1,nib,z,nib<(t.param==1 ? 9:15));
            if(nib<(t.param==1 ? 9:15))begin
              rejection_bursts.sample(t.core,t.mode,t.param,reject_run);reject_run=0;
            end else begin reject_run++;if(reject_run>max_reject_run)max_reject_run=reject_run;end
            if(nib<(t.param==1 ? 9:15))begin accept_mask|=1<<z;count++;accepted++;end
          end
          secret_compaction.sample(accept_mask,count);pos+=n;base+=n;
        end
      end
      2:begin
        width=t.param==0 ? 18:20;gamma=t.param==0 ? 131072:524288;
        foreach(t.cov_sizes[k])begin
          base=0;
          while(base<t.cov_sizes[k] && accepted<256)begin
            n=t.cov_sizes[k]-base;if(n>8)n=8;
            if(width==18)mask18_alignment.sample(reservoir.size(),n);
            else mask20_alignment.sample(reservoir.size(),n);
            for(int z=0;z<n;z++)for(int bit_index=0;bit_index<8;bit_index++)
              reservoir.push_back(t.cov_bytes[pos+z][bit_index]);
            while(reservoir.size()>=width && accepted<256)begin
              field=0;for(int bit_index=0;bit_index<width;bit_index++)begin b=reservoir.pop_front();field|=int'(b)<<bit_index;end
              mask_fields.sample(width==20,mask_class(field,gamma));accepted++;
            end
            pos+=n;base+=n;
          end
        end
      end
      3:begin
        foreach(polynomial[k])polynomial[k]=0;
        i=256-(t.param==0 ? 39:(t.param==1 ? 49:60));pos=8;sign_number=0;
        while(i<256 && pos<t.cov_bytes.size())begin
          j=t.cov_bytes[pos];pos++;
          challenge_decisions.sample(t.param,j>i,j==i,j<=i && polynomial[j]!=0);
          if(j<=i)begin
            rejection_bursts.sample(t.core,t.mode,t.param,reject_run);reject_run=0;
          end else begin reject_run++;if(reject_run>max_reject_run)max_reject_run=reject_run;end
          if(j<=i)begin
            polynomial[i]=polynomial[j];
            polynomial[j]=1-2*int'(t.cov_bytes[sign_number/8][sign_number%8]);
            sign_number++;i++;
          end
        end
      end
    endcase
    $fdisplay(fd,"%0d,%0d,%0d,%0d,256,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",t.id,t.core,t.mode,t.param,t.cov_bytes.size(),t.cov_sizes.size(),t.cov_paired,t.cov_switched,t.cov_reused,t.cov_prev_mode,t.cov_out_stall,t.cov_input_block,t.cov_status_stall);
    $fflush(fd);
    $fdisplay(robust_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",t.id,t.core,t.mode,t.param,max_reject_run,t.cov_out_stall,t.cov_status_stall,t.cov_sizes.size());
    $fflush(robust_fd);
  endfunction
  function void report_phase(uvm_phase phase);
    real pct[15],sum=0;
    string names[15]='{"checked_polynomial","input_format","scheduling","mode_transitions","matrix_candidates","secret_candidates","secret_compaction","mask_fields","mask18_alignment","mask20_alignment","challenge_decisions","coefficient_shape","stream_context","rejection_bursts","backpressure_context"};
    int summary_fd=$fopen({prefix,"_functional_summary.csv"},"w");
    pct[0]=checked_polynomial.get_inst_coverage();pct[1]=input_format.get_inst_coverage();pct[2]=scheduling.get_inst_coverage();
    pct[3]=mode_transitions.get_inst_coverage();pct[4]=matrix_candidates.get_inst_coverage();pct[5]=secret_candidates.get_inst_coverage();
    pct[6]=secret_compaction.get_inst_coverage();pct[7]=mask_fields.get_inst_coverage();pct[8]=mask18_alignment.get_inst_coverage();
    pct[9]=mask20_alignment.get_inst_coverage();pct[10]=challenge_decisions.get_inst_coverage();pct[11]=coefficient_shape.get_inst_coverage();
    pct[12]=stream_context.get_inst_coverage();pct[13]=rejection_bursts.get_inst_coverage();pct[14]=backpressure_context.get_inst_coverage();
    if(!summary_fd)`uvm_fatal("COV_FILE","Cannot create functional summary")
    $fdisplay(summary_fd,"group,percent");
    foreach(pct[k])begin
      sum+=pct[k];$fdisplay(summary_fd,"%s,%0.6f",names[k],pct[k]);
      `uvm_info("FUNCTIONAL_GROUP",$sformatf("%s: %0.2f%%",names[k],pct[k]),UVM_NONE)
    end
    $fdisplay(summary_fd,"overall_equal_group_mean,%0.6f",sum/15.0);
    $fdisplay(summary_fd,"credited_jobs,%0d",credited_jobs);$fclose(summary_fd);
    `uvm_info("FUNCTIONAL_OVERALL",$sformatf("%0.2f%% = arithmetic mean of15 group instance percentages; %0d scoreboard-accepted complete jobs; full gap review still required",sum/15.0,credited_jobs),UVM_NONE)
    $fclose(fd);
    $fclose(robust_fd);
  endfunction
endclass
