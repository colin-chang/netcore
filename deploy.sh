#!/usr/bin/env sh

set -e

gitbook build
cd _book
rm -f sitemap.xml
rm -f deploy.sh

git init
git add -A
git commit -m 'deploy'

git push -f git@github.com:colin-chang/netcore.git master:gh-pages

cd -
