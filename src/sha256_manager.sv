module sha256_manager #(
    parameter  SHA_IF_DATA_W = 256,
    parameter  SHA_IF_BITS_W = $clog2(256),
    parameter  SHA_IF_BYTES = 256/8,
    parameter  SHA_IF_BYTES_W = $clog2(SHA_IF_BYTES),
    parameter  SHA256_DIGEST_W = 256,
    parameter  SHA256_BLOCK_W = 512,
    parameter  SHA256_BLOCK_BYTES = 512/8,
    parameter  SHA256_BLOCK_BYTES_W = $clog2(SHA256_BLOCK_BYTES)
)
(
     input  logic   clk
    ,input  logic   rst
    
    ,input  logic                           src_manager_data_val                   
    ,input  logic   [SHA_IF_DATA_W-1:0]     src_manager_data
    ,input  logic                           src_manager_data_last
    ,output logic                           manager_src_rdy

    ,output logic                           manager_dst_digest_val
    ,output logic   [SHA256_DIGEST_W-1:0]   manager_dst_digest
    ,input  logic                           dst_manager_digest_rdy
                   
    ,output logic                           manager_core_init
    ,output logic                           manager_core_next
    ,output logic                           manager_core_mode
    ,output logic   [SHA256_BLOCK_W-1:0]    manager_core_block
    ,input  logic                           core_manager_ready

    ,input  logic   [SHA256_DIGEST_W-1:0]   core_manager_digest
    ,input  logic                           core_manager_digest_valid
);

    typedef enum logic[2:0] {
        READY = 3'b0,
        DATA_INPUT_UPPER = 3'b1,
        DATA_INPUT_LOWER = 3'd2,
        DATA_INPUT_LAST = 3'd3,
        DIGEST_OUTPUT_WAIT = 3'd4,
        DIGEST_OUTPUT = 3'd5,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    logic   [SHA256_DIGEST_W-1:0]   digest_reg;
    logic   [SHA256_DIGEST_W-1:0]   digest_next;
    logic                           store_digest;

    logic   [SHA_IF_DATA_W-1:0]     block_upper_reg;
    logic   [SHA_IF_DATA_W-1:0]     block_upper_next;
    logic   [SHA_IF_DATA_W-1:0]     block_lower_reg;
    logic   [SHA_IF_DATA_W-1:0]     block_lower_next;

    logic                           write_block_upper;
    logic                           write_block_lower;

    logic                           init_block_reg;
    logic                           init_block_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY; 
            digest_reg <= '0;
            block_upper_reg <= '0;
            init_block_reg <= '0;
        end
        else begin
            state_reg <= state_next; 
            digest_reg <= digest_next;
            block_upper_reg <= block_upper_next;
            block_lower_reg <= block_lower_next;
            init_block_reg <= init_block_next;
        end
    end

    assign manager_dst_digest = digest_next;
    assign manager_core_block = {block_upper_reg, block_lower_reg};
    assign manager_core_mode = 1'b1;

    assign block_upper_next = write_block_upper
                            ? src_manager_data
                            : block_upper_reg;

    assign block_lower_next = write_block_lower
                            ? src_manager_data
                            : block_lower_reg;

    assign digest_next = store_digest
                        ? core_manager_digest
                        : digest_reg;

    always_comb begin
        manager_core_init = 1'b0;
        manager_core_next = 1'b0;
        manager_src_rdy = 1'b0;
        manager_dst_digest_val = 1'b0;

        write_block_upper = 1'b0;
        write_block_lower = 1'b0;
        store_digest = 1'b0;

        init_block_next = init_block_reg;
        state_next = state_reg;
        case (state_reg)
            READY: begin
                manager_src_rdy = 1'b1;

                write_block_upper = src_manager_data_val;
                init_block_next = 1'b1;
                if (src_manager_data_val) begin
                    state_next = DATA_INPUT_LOWER; 
                end
                else begin
                    state_next = READY;
                end
            end
            DATA_INPUT_LOWER: begin
                manager_src_rdy = 1'b1;
                write_block_lower = src_manager_data_val;
                if (src_manager_data_val) begin
                    if (src_manager_data_last) begin
                        state_next = DATA_INPUT_LAST; 
                    end
                    else begin
                        state_next = DATA_INPUT_UPPER;
                    end
                end
                else begin
                    state_next = DATA_INPUT_LOWER; 
                end
            end
            DATA_INPUT_UPPER: begin
                manager_src_rdy = core_manager_ready;
                manager_core_init = init_block_reg & src_manager_data_val;
                manager_core_next = ~init_block_reg & src_manager_data_val;

                if (core_manager_ready & src_manager_data_val) begin
                    init_block_next = 1'b0;
                    write_block_upper = 1'b1;
                    state_next = DATA_INPUT_LOWER;
                end
                else begin
                    state_next = DATA_INPUT_UPPER; 
                end
            end
            DATA_INPUT_LAST: begin
                manager_core_init = init_block_reg;
                manager_core_next = ~init_block_reg;

                if (core_manager_ready) begin
                    state_next = DIGEST_OUTPUT_WAIT;
                end
                else begin
                    state_next = DATA_INPUT_LAST; 
                end
            end
            DIGEST_OUTPUT_WAIT: begin
                manager_dst_digest_val = core_manager_digest_valid;
                store_digest = core_manager_digest_valid;
                if (core_manager_digest_valid) begin
                    if (dst_manager_digest_rdy) begin
                        state_next = READY;
                    end
                    else begin
                        state_next = DIGEST_OUTPUT;
                    end
                end
                else begin
                    state_next = DIGEST_OUTPUT_WAIT;
                end
            end
            DIGEST_OUTPUT: begin
                manager_dst_digest_val = 1'b1;
                if (dst_manager_digest_rdy) begin
                    state_next = READY; 
                end
                else begin
                    state_next = DIGEST_OUTPUT;
                end
            end
            default: begin
                manager_core_init = 'X;
                manager_core_next = 'X;
                manager_src_rdy = 'X;
                manager_dst_digest_val = 'X;

                write_block_upper = 'X;
                write_block_lower = 'X;
                store_digest = 'X;

                init_block_next = 'X;
                state_next = UND;
            end
        endcase
    end


endmodule
