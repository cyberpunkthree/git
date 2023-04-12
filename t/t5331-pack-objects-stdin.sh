#!/bin/sh

test_description='pack-objects --stdin'
GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'pack-objects --stdin with duplicate packfile' '
	test_when_finished "rm -fr repo" &&

	git init repo &&
	(
		cd repo &&
		test_commit "commit" &&
		git repack -ad &&

		(
			basename .git/objects/pack/pack-*.pack &&
			basename .git/objects/pack/pack-*.pack
		) >packfiles &&

		git pack-objects --stdin-packs generated-pack <packfiles &&
		test_cmp generated-pack-*.pack .git/objects/pack/pack-*.pack
	)
'

test_done
