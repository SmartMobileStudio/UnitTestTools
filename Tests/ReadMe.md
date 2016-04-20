Tests
-----

This directory should only contain scripts/projects that are meant to be compiled by the command-line compiler unit test. There are two sub directories: 'Fail' and 'Success'

The 'Fail' directory should only contain scripts/projects that are known to fail. When they fail they should return a certain error message. They should not crash the compiler.

The 'Success' directory should only contain scripts/projects that compile and potentially run without errors. There might be warnings or hints, but they are expected to compile at least.

When started, the unit test tool scans for *.pas files and tries to compile and these. For scripts that are expected to fail, the error log is compared with the content of a file of the same name and the concatenated extension '.error'. If the text does not match the test is marked as 'failed'.

If the script succeeds to compile the compiled JavaScript output is compared with the content of a file of the same name and the concatenated extension '.js'. If the text does not match the test is marked as 'failed'.

In addition to that, the compiler output can be compared by comparing the content of a file of the same name and the concatenated extension '.out'. If the text does not match the test is marked as 'failed'.

Once the compilation succeeded, the unit test tries to execute the code. So far only Node.js is executed, which permits the use of browser specific APIs. The compiler result is then compared with the content of a file of the same name and the concatenated extension '.result'. If the text does not match the test is marked as 'failed'.    

In total a script file named 'Example.pas' can be checked for

* Compiler messages (file 'Example.pas.out')
* Compiler errors (file 'Example.pas.error')
* Compiler output (file 'Example.pas.js')
* Node.js output (file 'Example.pas.result')

For each compilation the output file is deleted. In the above example the file to be deleted would be named 'Example.js' (vs. 'Example.pas.js' which is kept).