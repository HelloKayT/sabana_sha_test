// Copyright 2022 Sabana Technologies, Inc
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module sabana (
  input  logic clock,
  input  logic reset,
  input  logic start,
  output logic finish,
  input  logic [32-1:0] input_data_32_in,
  input  logic input_data_32_empty,
  output logic input_data_32_pop,
  output logic [32-1:0] output_data_32_out,
  output logic output_data_32_push,
  input  logic output_data_32_full
);

    typedef enum logic[1:0]{
        IDLE = 2'd0,
        RUNNING = 2'd1,
        FINISH = 2'd2,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;
    
    logic               src_n_to_w_val;
    logic   [32-1:0]    src_n_to_w_data;
    logic               n_to_w_src_rdy;

    logic               n_to_w_dst_val;
    logic   [256-1:0]   n_to_w_dst_data;
    logic               dst_n_to_w_rdy;

    logic               manager_core_init;
    logic               manager_core_next;
    logic               manager_core_mode;
    logic   [512-1:0]   manager_core_block;
    logic               core_manager_ready;

    logic   [256-1:0]   core_manager_digest;
    logic               core_manager_digest_valid;
    
    logic               src_w_to_n_val;
    logic   [256-1:0]   src_w_to_n_data;
    logic               w_to_n_src_rdy;

    logic               w_to_n_dst_val;
    logic   [32-1:0]    w_to_n_dst_data;
    logic               w_to_n_dst_last;
    logic               dst_w_to_n_rdy;
    
    logic               manager_dst_digest_val;
    logic   [256-1:0]   manager_dst_digest;
    logic               dst_manager_digest_rdy;

    always_ff @(posedge clock) begin
        if (reset) begin
            state_reg <= IDLE;
        end
        else begin
            state_reg <= state_next;
        end
    end

    assign finish = state_reg == FINISH;

    always_comb begin
        state_next = state_reg;
        case (state_reg)
            IDLE: begin
                if (start) begin
                    state_next = RUNNING;
                end
            end
            RUNNING: begin
                if (w_to_n_dst_last & w_to_n_dst_val & dst_w_to_n_rdy) begin
                    state_next = FINISH;
                end
            end
            FINISH: begin
                state_next = FINISH;
            end
        endcase
    end

    assign src_n_to_w_val = ~input_data_32_empty & (state_reg == RUNNING);
    assign src_n_to_w_data = input_data_32_in;
    assign input_data_32_pop = src_n_to_w_val & n_to_w_src_rdy;

  // your code here
    narrow_to_wide #(
         .IN_DATA_W     (32)
        ,.OUT_DATA_ELS  (8)
    ) input_convert (
         .clk   (clock    )
        ,.rst   (reset    )
    
        ,.src_n_to_w_val    (src_n_to_w_val     )
        ,.src_n_to_w_data   (src_n_to_w_data    )
        ,.src_n_to_w_keep   ('1)
        ,.src_n_to_w_last   ()
        ,.n_to_w_src_rdy    (n_to_w_src_rdy     )
    
        ,.n_to_w_dst_val    (n_to_w_dst_val     )
        ,.n_to_w_dst_data   (n_to_w_dst_data    )
        ,.n_to_w_dst_keep   ()
        ,.n_to_w_dst_last   ()
        ,.dst_n_to_w_rdy    (dst_n_to_w_rdy     )
    );

    sha256_manager manager (
         .clk   (clock  )
        ,.rst   (reset  )
        
        ,.src_manager_data_val      (n_to_w_dst_val     )
        ,.src_manager_data          (n_to_w_dst_data    )
        ,.src_manager_data_last     (1'b1)
        ,.manager_src_rdy           (dst_n_to_w_rdy     )
    
        ,.manager_dst_digest_val    (manager_dst_digest_val     )
        ,.manager_dst_digest        (manager_dst_digest         )
        ,.dst_manager_digest_rdy    (dst_manager_digest_rdy     )

        ,.manager_core_init         (manager_core_init          )
        ,.manager_core_next         (manager_core_next          )
        ,.manager_core_mode         (manager_core_mode          )
        ,.manager_core_block        (manager_core_block         )
        ,.core_manager_ready        (core_manager_ready         )
                                                                
        ,.core_manager_digest       (core_manager_digest        )
        ,.core_manager_digest_valid (core_manager_digest_valid  )
    );

    sha256_core DUT (
         .clk           (clock  )
        ,.reset_n       (~reset )

        ,.init          (manager_core_init          )
        ,.next          (manager_core_next          )
        ,.mode          (manager_core_mode          )

        ,.block         (manager_core_block         )

        ,.ready         (core_manager_ready         )
        ,.digest        (core_manager_digest        )
        ,.digest_valid  (core_manager_digest_valid  )
    );

    assign src_w_to_n_val = manager_dst_digest_val;
    assign src_w_to_n_data = manager_dst_digest;
    assign dst_manager_digest_rdy = w_to_n_src_rdy;

    wide_to_narrow #(
         .OUT_DATA_W    (32 )
        ,.IN_DATA_ELS   (8  )
    ) output_convert (
         .clk   (clock    )
        ,.rst   (reset    )
    
        ,.src_w_to_n_val    (src_w_to_n_val     )
        ,.src_w_to_n_data   (src_w_to_n_data    )
        ,.src_w_to_n_keep   ('1)
        ,.src_w_to_n_last   (1'b1)
        ,.w_to_n_src_rdy    (w_to_n_src_rdy     )
    
        ,.w_to_n_dst_val    (w_to_n_dst_val     )
        ,.w_to_n_dst_data   (w_to_n_dst_data    )
        ,.w_to_n_dst_keep   ()
        ,.w_to_n_dst_last   (w_to_n_dst_last    )
        ,.dst_w_to_n_rdy    (dst_w_to_n_rdy     )
    );

    assign output_data_32_out = w_to_n_dst_data;
    assign output_data_32_push = w_to_n_dst_val;
    assign dst_w_to_n_rdy = ~output_data_32_full;

endmodule
