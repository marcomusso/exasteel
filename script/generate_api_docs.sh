#!/bin/sh

echo "Creating docs from APIs definition."

echo "Will create: templates/api/v1/docs.html.ep"

echo ". Header"
echo -e "%layout 'default';\n%title 'API Docs - Exasteel';\n" >templates/api/v1/docs.html.ep
echo -e "%layout 'default';\n%title 'API Docs - Exasteel';\n" >templates/api/private.html.ep

echo ". pod2html Public APIs"
pod2html --infile lib/Exasteel/Controller/Public_APIs.pm --outfile templates/api/v1/docs.html.ep
echo ". pod2html Private APIs"
pod2html --infile lib/Exasteel/Controller/Private_APIs.pm --outfile templates/api/docs.html.ep

[ -f pod2htmd.tmp ] && rm -f pod2htmd.tmp
