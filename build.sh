#!/usr/bin/bash
mdfolders="pages _posts"
datefile=_data/dates.yaml
rm $datefile
touch $datefile
 
# create modification date files for content
for page in `find $mdfolders -name "*.md"`
do
    page_base=`basename $page .md`
    if [ `head -1 $page | grep '^---\s*'` ]; then
        modified=`stat $page | sed -n 's/^Modify:\s*\([^.]\+\).*/\1/ p'`
        moddate=${modified% *}
        case $page in
            *_posts*)
                credate=`basename $page | cut -c "1-10"`
                ;;
            *)
                credate=`stat $page | sed -n 's/\s*Birth:\s*\([^ ]\+\).*/\1/ p'`
                ;;
        esac
#        datefile=_includes/.dates/`dirname $page`/`basename $page .md`.yaml
        echo "adding $page_base : (cdate: $credate - mtime: $modified)"
#        mkdir -p _includes/.dates/`dirname $page`
        echo "- path: $page" >> $datefile
        if [ "$credate" = "$moddate" ]
        then
            echo "  timestamp: 'created $modified'" >> $datefile
        else
            echo "  timestamp: 'created $credate // last modified $modified'" >> $datefile
        fi
    else
        echo skip: no front matter $page
    fi
done