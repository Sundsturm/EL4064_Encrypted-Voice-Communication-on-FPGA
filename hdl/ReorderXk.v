module ReorderXk #(
    parameter   DEPTH   = 33, // 25% of 128 + 1
    parameter   WIDTH   = 16
)(
    input                   clock,
    input                   reset,

    input                   di_en,
    input       [WIDTH-1:0] in_real,
    input       [WIDTH-1:0] in_imag,
    
    input       [23:0]      current_key_l, // key for left side of FFT
    input       [23:0]      current_key_r, // key for right side of FFT

    output                  do_en,
    output      reg [6:0]   do_count,
    output      [WIDTH-1:0] out_real,
    output      [WIDTH-1:0] out_imag
);

reg [6:0]       di_count;
reg             init_di_count, init_do_count;

reg [1:0]       sync        [0:DEPTH-1];
reg [15:0]      buf_re      [0:DEPTH-1];
reg [15:0]      buf_im      [0:DEPTH-1];

/////////////////////////////////

initial begin 
    init_di_count <= 1'b0;
    init_do_count <= 1'b0;
end

// counter for input data
always @(posedge di_en) begin 
    //di_count <= 1'b0;
    init_di_count <= 1'b1;
    #28;
    init_di_count <= 1'b0;
end

// counter for output data
always @(posedge do_en) begin
    //do_count <= 1'b0;
    init_do_count <= 1'b1;
    #28;
    init_do_count <= 1'b0;
end

always @(posedge clock) begin 
    if (reset) begin 
        di_count <= 1'b0;
        do_count <= 1'b0;
    end else if (init_di_count | init_do_count) begin
        if (init_di_count) begin
            di_count <= 1'b0;
        end
        if (init_do_count) begin
            do_count <= 1'b0;
        end
    end else begin
        di_count <= di_count + 1'b1;
        do_count <= di_count + 1'b1;
    end
end

// scrambler + buffer
integer n;
integer p, q, r;
always @(posedge clock) begin

    if (reset) begin
        for (n = DEPTH - 1; n > 0; n = n - 1) begin 
            buf_re[n] <= 1'bx;
            buf_im[n] <= 1'bx;
            sync[n]   <= 1'bx;
        end

    end else begin 
        for (n = DEPTH - 1; n > 0; n = n - 1) begin 
            buf_re[n] <= buf_re[n - 1];
            buf_im[n] <= buf_im[n - 1];
            sync[n]   <= sync[n - 1];
        end

        buf_re[0]   <= in_real;
        buf_im[0]   <= in_imag;
        sync[0]     <= di_en;

    end 

    if (current_key_l != 1'b0) begin
        
        if (di_count == 7'd32) begin
            
            // reminder: first-in now first-out
            // is at index 31; index 0 is last in 

            r = 21;
            for (p = 32; p > 0; p = p - 4) begin

                q = 31  - (current_key_l[r+:3] * 4);

                buf_re[p  ] <= buf_re[q  ];
                buf_re[p-1] <= buf_re[q-1];
                buf_re[p-2] <= buf_re[q-2];
                buf_re[p-3] <= buf_re[q-3];
                
                buf_im[p  ] <= buf_im[q  ];
                buf_im[p-1] <= buf_im[q-1];
                buf_im[p-2] <= buf_im[q-2];
                buf_im[p-3] <= buf_im[q-3];
                
                sync[p  ]   <= sync[q    ];
                sync[p-1]   <= sync[q-1  ];
                sync[p-2]   <= sync[q-2  ];
                sync[p-3]   <= sync[q-3  ];

                r = r - 3;
            end

        end else if (di_count == 0) begin

            r = 21;
            for (p = 32; p > 0; p = p - 4) begin

                q = 31  - (current_key_r[r+:3] * 4);

                buf_re[p  ] <= buf_re[q  ];
                buf_re[p-1] <= buf_re[q-1];
                buf_re[p-2] <= buf_re[q-2];
                buf_re[p-3] <= buf_re[q-3];
                
                buf_im[p  ] <= buf_im[q  ];
                buf_im[p-1] <= buf_im[q-1];
                buf_im[p-2] <= buf_im[q-2];
                buf_im[p-3] <= buf_im[q-3];
                
                sync[p  ]   <= sync[q    ];
                sync[p-1]   <= sync[q-1  ];
                sync[p-2]   <= sync[q-2  ];
                sync[p-3]   <= sync[q-3  ];

                r = r - 3;
            end
        end

    end
end

assign  out_real    = buf_re[DEPTH-1];
assign  out_imag    = buf_im[DEPTH-1];
assign  do_en       = sync[DEPTH-1  ]; 

endmodule