#!/bin/sh

test_description='pack-objects --stdin'
GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

packed_objects() {
	git show-index <"$1" >tmp-object-list &&
	cut -d' ' -f2 tmp-object-list &&
	rm tmp-object-list
 }

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

test_expect_success 'pack-objects --stdin with same packfile excluded and included' '
	test_when_finished "rm -fr repo" &&

	git init repo &&
	(
		cd repo &&
		test_commit "commit" &&
		git repack -ad &&

		(
			basename .git/objects/pack/pack-*.pack &&
			printf "^%s\n" "$(basename .git/objects/pack/pack-*.pack)"
		) >packfiles &&

		git pack-objects --stdin-packs generated-pack <packfiles &&
		packed_objects generated-pack-*.idx >packed-objects &&
		test_must_be_empty packed-objects
	)
'

test_expect_success 'pack-objects --stdin with packfiles from alternate object database' '
	test_when_finished "rm -fr shared member" &&

	# Set up a shared repository with a single packfile.
	git init shared &&
	test_commit -C shared "shared-objects" &&
	git -C shared repack -ad &&
	basename shared/.git/objects/pack/pack-*.pack >packfile &&

	# Set up a repository that is connected to the shared repository. This
	# repository has no objects on its own, but we still expect to be able
	# to pack objects from its alternate.
	git clone --shared shared member &&
	git -C member pack-objects --stdin-packs generated-pack <packfile &&
	test_cmp shared/.git/objects/pack/pack-*.pack member/generated-pack-*.pack
'

test_expect_success 'pack-objects --stdin with packfiles from main and alternate object database' '
	test_when_finished "rm -fr shared member" &&

	# Set up a shared repository with a single packfile.
	git init shared &&
	test_commit -C shared "shared-commit" &&
	git -C shared repack -ad &&

	# Set up a repository that is connected to the shared repository. This
	# repository has a second packfile so that we can verify that it is
	# possible to write packs that include packfiles from different object
	# databases.
	git clone --shared shared member &&
	test_commit -C member "local-commit" &&
	git -C member repack -dl &&

	(
		basename shared/.git/objects/pack/pack-*.pack  &&
		basename member/.git/objects/pack/pack-*.pack
	) >packfiles &&

	(
		packed_objects shared/.git/objects/pack/pack-*.idx &&
		packed_objects member/.git/objects/pack/pack-*.idx
	) | sort >expected-objects &&

	git -C member pack-objects --stdin-packs generated-pack <packfiles &&
	packed_objects member/generated-pack-*.idx | sort >actual-objects &&
	test_cmp expected-objects actual-objects
'

test_done
