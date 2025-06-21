module BinToBCD(
    input  wire [13:0] bin,    // 14-bit binary input, max 9999
    output reg  [3:0] bcd3,    // Thousands digit
    output reg  [3:0] bcd2,    // Hundreds digit
    output reg  [3:0] bcd1,    // Tens digit
    output reg  [3:0] bcd0     // Ones digit
);
    integer i;
    reg [17:0] shift; // 14 bits for input + 4 bits for BCD = 18 bits

    always @(*) begin
        // Initialize shift register
        shift = 18'd0;
        shift[13:0] = bin;

        // Double Dabble (shift-add-3) algorithm for BCD conversion
        for (i = 0; i < 14; i = i + 1) begin
            // Add 3 to BCD digits >= 5 before shifting
            if (shift[17:14] >= 5) shift[17:14] = shift[17:14] + 3;
            if (shift[13:10] >= 5) shift[13:10] = shift[13:10] + 3;
            if (shift[9:6]   >= 5) shift[9:6]   = shift[9:6]   + 3;
            if (shift[5:2]   >= 5) shift[5:2]   = shift[5:2]   + 3;
            // Shift left by 1
            shift = shift << 1;
        end

        // Assign BCD outputs
        bcd3 = shift[17:14]; // Thousands
        bcd2 = shift[13:10]; // Hundreds
        bcd1 = shift[9:6];   // Tens
        bcd0 = shift[5:2];   // Ones
    end
endmodule