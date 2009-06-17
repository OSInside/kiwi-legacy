This is a command line tool to join PDF files. When you have to deal with
joining several files it is much faster than using Adobe Acrobat. However, it
will not join PDF files which have security enabled, it will generate an error.
It REQUIRES a current Java Runtime Environment (JRE).The code is actually
from the iText project. I added a shell script and created an installer. Hope
people find it as useful as I did.

To install download and decompress the tar.gz file. Place 'PDF.jar' in
/usr/lib/ and, 'joinPDF' and 'splitPDF' in /usr/bin/.

To use the application, open a Terminal window and type joinPDF. The structure
of the command is as follows:

joinPDF destfile file1 file2 [file3 ...]
(This tools needs at least 3 parameters:)

splitPDF srcfile destfile1 destfile2 pagenumber
splitPDF srcfile


cp ./install/PDF.jar /usr/lib/
cp ./install/joinPDF /usr/bin/
cp ./install/splitPDF /usr/bin/

