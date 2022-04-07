#!/bin/sh

test_description='git p4 metadata encoding

This test checks that the import process handles inconsistent text
encoding in p4 metadata (author names, commit messages, etc) without
failing, and produces maximally sane output in git.'

. ./lib-git-p4.sh

# HORRIBLE HACK TO ENSURE PYTHON VERSION!
# (also requires calling "git p4.py", rather than "git p4")
python_major_version=$(python -V 2>&1 | cut -c  8)
python_2_exists=$(/usr/bin/python2 -V 2>&1)
if ! test "$python_major_version" = '2' && test "$python_2_exists"
then
	mkdir temp_python
	export PATH="$(pwd)/temp_python:$PATH"
	ln -s /usr/bin/python2 temp_python/python
fi

python_major_version=$(python -V 2>&1 | cut -c  8)
if ! test "$python_major_version" = '2'
then
	skip_all='skipping python3-specific git p4 tests; python2 not available'
	test_done
fi

###############################
## SECTION REPEATED IN t9835 ##
###############################

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'init depot' '
	(
		cd "$cli" &&

		touch file1 &&
		p4 add file1 &&
		p4 submit -d "first CL has some utf-8 tǣxt" &&

		touch file2 &&
		p4 add file2 &&
		p4 submit -d "$(echo second CL has some latin-1 tæxt |
		  iconv -f utf8 -t latin1)" &&

		touch file3 &&
		p4 add file3 &&
		p4 submit -d "$(echo second CL has sœme cp-1252 tæxt |
		  iconv -f utf8 -t cp1252)"
	)
'

test_expect_success 'clone non-utf8 repo with strict encoding' '
	test_when_finished cleanup_git &&
	test_must_fail git -c git-p4.encodingStrategy=strict p4.py clone --dest="$git" //depot@all 2>err &&
	grep "Decoding returned data failed!" err
'

test_expect_success 'check utf-8 contents with legacy strategy' '
	test_when_finished cleanup_git &&
	git -c git-p4.encodingStrategy=legacy p4.py clone --dest="$git" //depot@all &&
	(
		cd "$git" &&
		git log >actual &&
		grep "some utf-8 tǣxt" actual
	)
'

test_expect_success 'check utf-8 contents with fallback strategy' '
	test_when_finished cleanup_git &&
	git -c git-p4.encodingStrategy=fallback p4.py clone --dest="$git" //depot@all &&
	(
		cd "$git" &&
		git log >actual &&
		grep "some utf-8 tǣxt" actual
	)
'

test_expect_success 'check latin-1 contents with fallback strategy' '
	test_when_finished cleanup_git &&
	git -c git-p4.encodingStrategy=fallback p4.py clone --dest="$git" //depot@all &&
	(
		cd "$git" &&
		git log >actual &&
		grep "some latin-1 tæxt" actual
	)
'

test_expect_success 'check cp-1252 contents with fallback strategy' '
	test_when_finished cleanup_git &&
	git -c git-p4.encodingStrategy=fallback p4.py clone --dest="$git" //depot@all &&
	(
		cd "$git" &&
		git log >actual &&
		grep "sœme cp-1252 tæxt" actual
	)
'

############################
## / END REPEATED SECTION ##
############################

test_done
