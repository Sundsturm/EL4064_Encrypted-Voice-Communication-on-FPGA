
// designed to work with 128 bit long frames
// and employs a 128-point FFT
// single-path pipeline with constant delay (in clock cycles)

module Scrambler_TOP(

    // to be equivalent to sampling clock
    input           clock,
    input           reset,

    // set as HIGH when given valid input in 
    // in_real and shift_key
    // remain HIGH as long as their is valid input
    // only turn LOW when no longer given valid input
    input           di_en,

    // key for a given 128 bit long frame
    // will not scramble for input 24'b0, but otherwise will
    input   [23:0]  shift_key,

    // real (not imaginary) input only to represent mono audio data x[n]
    input   [15:0]  in_real,

    // LOW initially but HIGH after valid output is ready
    // will remain HIGH as long as there is valid output
    // valid output is defined as being produced from a valid input
    // (the corresponding input data sample was associated with HIGH di_en)
    output          do_en,

    // real (not imaginary) output to represent scrambled audio x_s[n]
    output  [15:0]  out_real
);

    ////////////////////////////////////////////////////////////////////////

    /*

    Pipeline:
                        Generate Permutation Key ---|
                                                    V
    FFT ---------> Reverse Bit + Scaling ---------> ReorderXk ---------> IFFT ---------> Reverse Bit
      do_en >    di_en   >        do_en   >  di_in  >   do_en  > di_in > do_en   > di_in   >        do_en

    */

    // Permutatin key generation output
    wire [23:0] key_L, key_R;

    // FFT output
    wire        do_en_fft;                  // output enable
    wire [15:0] fft_re, fft_im;             // real and imaginary outputs

    // Post-FFT Reverse Bit Order output
    wire        do_en_rev_fft;              // output enable
    wire [15:0] rev_fft_re, rev_fft_im;     // real and imaginary outputs
    wire [06:0] do_count_rev_fft;           // ignored

    // Scale by 128x post-FFT
    wire [15:0] scale_fft_re, scale_fft_im;

    // ReorderXk output
    wire        do_en_reorder;              // output enable
    wire [06:0] do_count_reorder;           // output counter (ignored)
    wire [15:0] reorder_re, reorder_im;     // real and imaginary outputs

    // IFFT output
    reg         reset_ifft;                 // reset reg specifically for IFFT
    wire        do_en_ifft;                 // output enable
    wire [15:0] ifft_re, ifft_im;           // real and imaginary outputs
                                            // ifft_re will be ignored, but we will still define a net for it

    // Post-IFFT Reverse Bit Order output
    wire        do_en_rev_ifft;             // output enable
    wire [15:0] rev_ifft_re, rev_ifft_im;   // real and imaginary outputs
    wire [06:0] do_count_rev_ifft;          // ignored


    ////////////////////////////////////////////////////////////////////////


    GenPermutationKey GenKey (
        .shift_key          (shift_key      ),  // i from top
        .permutation_key1   (key_L          ),  // o to Reorder module, left key
        .permutation_key2   (key_R          )   // o to Reorder module, right key
    );

    // - - - - - Pipeline start - - - - - //

    FFT FFT128 (
        .clock              (clock          ),  // i from top
        .reset              (reset          ),  // i from top
        .di_en              (di_en          ),  // i from top
        .di_re              (in_real        ),  // i from top
        .di_im              (16'b0          ),  // i (empty)
        .do_en              (do_en_fft      ),  // o to next module
        .do_re              (fft_re         ),  // o to next module
        .do_im              (fft_im         )   // o to next module
    );

    ReverseBitOrder PostFFTRev (
        .clock              (clock          ),  // i from top
        .di_en              (do_en_fft      ),  // i from prev module
        .di_re              (fft_re         ),  // i from prev module
        .di_im              (fft_im         ),  // i from prev module
        .do_en              (do_en_rev_fft  ),  // o to next module
        .do_count           (do_count_rev_fft), // o, ignored
        .do_re              (rev_fft_re     ),  // o to next module
        .do_im              (rev_fft_im     )   // o to next module
    );

    Mult128 ScaleFFT (
        .di_re              (rev_fft_re     ),
        .di_im              (rev_fft_im     ),
        .do_re              (scale_fft_re   ),
        .do_im              (scale_fft_im   )
    );

    ReorderXk Reorder (
        .clock              (clock          ),  // i from top
        .reset              (reset          ),  // i from top
        .di_en              (do_en_rev_fft  ),  // i from prev module
        .in_real            (scale_fft_re   ),  // i from prev module
        .in_imag            (scale_fft_im   ),  // i from prev module
        .current_key_l      (key_L          ),  // i from GenKey
        .current_key_r      (key_R          ),  // i from GenKey
        .do_en              (do_en_reorder  ),  // o to next module
        .do_count           (do_count_reorder), // o, ignored
        .out_real           (reorder_re     ),  // o to next module
        .out_imag           (reorder_im     )   // o to next module
    );

    initial begin
        reset_ifft <= 1'b1;
    end

    always @(posedge do_en_reorder) begin
        reset_ifft <= 1'b0;
    end

    FFT IFFT128 (
        .clock              (clock          ),  // i from top
        .reset              (reset_ifft     ),  // i specifically for ifft
        .di_en              (do_en_reorder  ),  // i from prev module
        .di_re              (reorder_im     ),  // i from prev module, re/im swap is intentional
        .di_im              (reorder_re     ),  // i from prev module, re/im swap is intentional
        .do_en              (do_en_ifft     ),  // o to next module
        .do_re              (ifft_re        ),  // o, ignored
        .do_im              (ifft_im        )   // o to next module
    );

    ReverseBitOrder PostIFFTRev (
        .clock              (clock          ),  // i from top
        .di_en              (do_en_ifft     ),  // i from prev module
        .di_re              (ifft_im        ),  // i from prev module
        .di_im              (16'b0          ),  // i, empty
        .do_en              (do_en_rev_ifft ),  // o to be assigned to top
        .do_count           (do_count_rev_ifft),// o, ignored
        .do_re              (rev_ifft_re    ),  // o to be assigned to top
        .do_im              (rev_ifft_im    )   // o, ignored
    );


    // - - - - - Pipeline end - - - - - //

    assign do_en = do_en_rev_ifft; // output enable
    assign out_real = rev_ifft_re; // output data
    

endmodule
