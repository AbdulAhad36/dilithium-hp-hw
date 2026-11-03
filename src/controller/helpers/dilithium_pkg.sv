// Published LightHD Figure2 bank roles. Zero-based RTL banks map BRAM1..4.
// Phase lifetimes,not a general-purpose region allocator,own these addresses.
package dilithium_pkg;
  localparam logic [22:0] Q=23'd8380417;
  localparam int BANK_WORDS=1024,WORD_BITS=92,POLY_WORDS=64;
  typedef enum logic [2:0] {
    PROC_ADD,PROC_SUB,PROC_P2R,PROC_DECOMPOSE,PROC_CNB,PROC_MHINT,PROC_USEHINT,PROC_PACK
  } process_op_e;
  typedef enum logic [3:0] {
    ROLE_Y,ROLE_S2,ROLE_T0,ROLE_ROW,ROLE_W0,ROLE_S1,ROLE_YHAT,
    ROLE_W1,ROLE_A,ROLE_Z,ROLE_CHAT,ROLE_R0,ROLE_ROW_COEFF,ROLE_PK_T1
  } role_e;
  typedef struct packed {
    logic valid;
    logic [1:0] bank;
    logic [9:0] base;
    logic [10:0] words;
  } span_t;
  typedef struct packed {
    logic valid,batch_last;logic [1:0] mode,param,bank;logic [9:0] base;
    logic [15:0] id,message_len;logic input_valid;logic [63:0] input_data;logic done_ready;
  } sample_request_t;
  typedef struct packed {
    logic ready,core,input_ready,done_valid,done_core;logic [15:0] done_id;
    logic [2:0] done_code;logic fault;logic [1:0] active;
  } sample_response_t;
  typedef struct packed {
    logic valid,mode;logic [15:0] id,message_len,output_len;
    logic input_valid;logic [63:0] input_data;logic output_ready,done_ready;
  } raw_request_t;
  typedef struct packed {
    logic ready,core,input_ready,output_valid,output_core;logic [15:0] output_id;
    logic [127:0] output_data;logic [4:0] output_bytes;
    logic done_valid,done_core;logic [15:0] done_id;
  } raw_response_t;
  typedef struct packed {
    logic valid;logic [1:0] op;logic accumulate;
    logic [1:0] a_bank,b_bank,c_bank,d_bank;logic [9:0] a_base,b_base,c_base,d_base;
    logic done_ready;
  } ntt_request_t;
  typedef struct packed {logic ready,done_valid,source_released;logic [1:0] done_code;} ntt_response_t;
  typedef struct packed {
    logic valid;process_op_e op;logic [1:0] param,kind;
    logic a_compact,b_enable,b_compact,low_enable,pack_enable,pack_store;
    logic [2:0] pack_op;logic [1:0] a_bank,b_bank,d_bank,h_bank;
    logic [9:0] a_base,b_base,d_base,h_base;logic done_ready,packed_ready,hint_enable,hint_ready;
  } process_request_t;
  typedef struct packed {
    logic ready,done_valid;logic [1:0] done_code;logic reject;logic [8:0] hint_weight;
    logic packed_valid;logic [63:0] packed_data;logic [6:0] packed_index;logic packed_last;
    logic hint_valid;logic [3:0] hint_mask;logic [5:0] hint_word;logic hint_last;
  } process_response_t;
  typedef struct packed {
    logic [1:0] command_valid;logic [1:0][3:0] mask,write;
    logic [1:0][3:0][9:0] base;logic [1:0][3:0][10:0] words;
    logic [1:0][3:0][1:0] mode;logic [1:0][3:0] write_valid;
    logic [1:0][3:0][91:0] write_data;logic [1:0][3:0][9:0] write_address;
    logic [1:0][3:0] read_ready,done_ready;
  } bank_request_t;
  typedef struct packed {
    logic [1:0] command_ready;logic [1:0][3:0] write_ready,read_valid;
    logic [1:0][3:0][91:0] read_data;logic [1:0][3:0][9:0] read_address;
    logic [1:0][3:0] read_last,done_valid,done_error;
  } bank_response_t;
  typedef struct packed {
    logic valid;logic [2:0] op;logic [1:0] param,bank;logic [9:0] base;logic [15:0] id;
    logic input_valid;logic [63:0] input_data;logic [6:0] input_index;
    logic [3:0] input_bytes;logic input_last,done_ready;
  } load_request_t;
  typedef struct packed {logic ready,input_ready,done_valid;logic [2:0] done_code;logic [15:0] done_id;} load_response_t;
  // Hint suffix formatting is ONE physical Process resource. Encoding takes
  // masks directly from MHint;the controller supplies only phase/row control.
  typedef struct packed {
    logic valid,cancel,feed_enable;logic [1:0] param;logic [15:0] id;
    logic [2:0] row;logic output_ready,done_ready;
  } hint_encode_request_t;
  typedef struct packed {
    logic ready,input_ready,result_valid,reject,output_valid;
    logic [63:0] output_data;logic [3:0] output_bytes,output_index;
    logic output_last;logic [15:0] output_id;logic done_valid;logic [1:0] done_code;
  } hint_encode_response_t;
  typedef struct packed {
    logic valid;logic [1:0] param;logic [15:0] id;
    logic input_valid;logic [63:0] input_data;logic [3:0] input_index,input_bytes;
    logic input_last,output_ready,done_ready;
  } hint_decode_request_t;
  typedef struct packed {
    logic ready,input_ready,output_valid;logic [3:0] output_hints;
    logic [2:0] output_row;logic [5:0] output_word;logic output_last;
    logic [15:0] output_id;logic done_valid;logic [2:0] done_code;logic [15:0] done_id;
  } hint_decode_response_t;
  typedef struct packed {
    sample_request_t sample;raw_request_t raw;ntt_request_t ntt;
    process_request_t poly_process;bank_request_t bank;load_request_t load;
    hint_encode_request_t hint_encode;hint_decode_request_t hint_decode;
  } request_t;
  typedef struct packed {
    sample_response_t sample;raw_response_t raw;ntt_response_t ntt;
    process_response_t poly_process;bank_response_t bank;load_response_t load;
    hint_encode_response_t hint_encode;hint_decode_response_t hint_decode;
    logic idle;
  } response_t;
  function automatic logic [3:0] rows(input logic [1:0] level);
    case(level) 0:return 4;1:return 6;2:return 8;default:return 0;endcase
  endfunction
  function automatic logic [3:0] columns(input logic [1:0] level);
    case(level) 0:return 4;1:return 5;2:return 7;default:return 0;endcase
  endfunction
  function automatic span_t span(input logic [1:0] level,input role_e role,
                                  input logic [4:0] index);
    span_t s;
    s='0;s.words=64;
    if(level!=3)case(role)
      ROLE_Y:begin s.valid=index<columns(level);s.bank=0;s.base={index[3:0],6'b0};end
      ROLE_S2:begin s.valid=index<rows(level);s.bank=0;s.base=10'd448+{index[3:0],6'b0};end
      ROLE_T0:begin s.valid=index<rows(level);s.bank=1;s.base=10'd64+{index[3:0],6'b0};end
      ROLE_ROW:begin s.valid=index==0;s.bank=1;s.base=0;end
      ROLE_W0:begin
        s.valid=index<rows(level);s.bank=1;
        s.base=index==7?10'd0:10'd576+{index[3:0],6'b0};
      end
      ROLE_S1:begin s.valid=index<columns(level);s.bank=2;s.base={index[3:0],6'b0};end
      ROLE_YHAT:begin s.valid=index<columns(level);s.bank=2;s.base=10'd448+{index[3:0],6'b0};end
      // Packed64-bit words in the low bits of the92-bit memory word.
      ROLE_W1:begin s.valid=index==0;s.bank=2;s.base=896;s.words=level==2?128:96;end
      // Nine slots are explicit for levels2/3. Sixteen at level5 is the
      // physical whole-bank capacity;the paper does not give its ring limit.
      ROLE_A:begin s.valid=index<(level==2?16:9);s.bank=3;s.base={index[3:0],6'b0};end
      ROLE_Z:begin s.valid=index<columns(level);s.bank=3;s.base={index[3:0],6'b0};end
      ROLE_CHAT:begin s.valid=index==0;s.bank=3;s.base=448;end
      ROLE_R0:begin s.valid=index<rows(level);s.bank=3;s.base=10'd512+{index[3:0],6'b0};end
      // The unused64-word tail of BRAM1 holds a row after INTT (Fig7).
      ROLE_ROW_COEFF:begin s.valid=index==0;s.bank=0;s.base=960;end
      // KeyGen-only external-serialization adaptation:packed t1 is retained
      // above its nine-slot A ring;no additional physical RAM is instantiated.
      ROLE_PK_T1:begin
        s.valid=index==0;s.bank=3;s.base=576;
        s.words=11'(rows(level))*11'd40;
      end
      default:s.valid=0;
    endcase
    if(!s.valid)s='0;
    return s;
  endfunction
endpackage
