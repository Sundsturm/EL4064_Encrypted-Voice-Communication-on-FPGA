fileID = fopen('test.html','w');

document_start = sprintf([ ... 
    '<!DOCTYPE html>' ...
    '<html>' ...
    '<head>' ...
    '<title>Hello, world!</title>' ...
    '</head>' ...
    '<body>'
]);

document_heading = sprintf([ ...
    '<h1>goertzel4 summary</h1>' ...
    '<h2>Version 1</h2>'
    ]);

document_end = sprintf([ ...
    '</body>' ...
    '</html>'
    ]);

fprintf(fileID, document_start);
fprintf(fileID, document_heading);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fileID,'%6s <strong>%12s</strong><br>','x','exp(x)');
fprintf(fileID,'%6.2f %12.8f\n',A);

fprintf(fileID, '<img src="barchart2.png" width="900px"/>');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fileID, document_end);

fclose(fileID);