```mermaid
flowchart TD

A[Input Signal x[n]] --> B[Sliding Window Buffer\n(window_size = 320)]
B --> C[DTMF Correlator]

subgraph Correlation
C --> C1[697 Hz I/Q]
C --> C2[941 Hz I/Q]
C --> C3[1477 Hz I/Q]
end

C1 --> D1[Power P697 = I²+Q²]
C2 --> D2[Power P941 = I²+Q²]
C3 --> D3[Power P1477 = I²+Q²]

D1 --> E[Score Computation]
D2 --> E
D3 --> E

E --> F[score_flag = P941 + P1477\nscore_mark = P697 + P1477]

F --> G[Adaptive Threshold\nTH = noise + α(peak-noise)]

G --> H[Comparator\nscore_flag > TH]

H --> I[Hysteresis / Persistence]

I --> J[Flag Detected]

J --> K[Peak Detector\n(max score_mark)]

K --> L[Sync Point Output]
```