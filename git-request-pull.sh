#!/bin/sh
# Copyright 2005, Ryan Anderson <ryan@michonline.com>
#
# This file is licensed under the GPL v2, or a later version
# at the discretion of Linus Torvalds.

USAGE='<start> <url> [<end>]'
LONG_USAGE='Summarizes the changes between two commits to the standard output,
and includes the given URL in the generated summary.'
SUBDIRECTORY_OK='Yes'
OPTIONS_KEEPDASHDASH=
OPTIONS_SPEC='git request-pull [options] start url [end]
--
p    show patch text as well
'

. git-sh-setup

GIT_PAGER=
export GIT_PAGER

patch=
while	case "$#" in 0) break ;; esac
do
	case "$1" in
	-p)
		patch=-p ;;
	--)
		shift; break ;;
	-*)
		usage ;;
	*)
		break ;;
	esac
	shift
done

base=$1 url=$2 head=${3-HEAD} status=0 branch_name=

headref=$(git symbolic-ref -q "$head")
if git show-ref -q --verify "$headref"
then
	branch_name=${headref#refs/heads/}
	if test "z$branch_name" = "z$headref" ||
		! git config "branch.$branch_name.description" >/dev/null
	then
		branch_name=
	fi
fi

tag_name=$(git describe --exact "$head^0" 2>/dev/null)

test -n "$base" && test -n "$url" || usage
baserev=$(git rev-parse --verify "$base"^0) &&
headrev=$(git rev-parse --verify "$head"^0) || exit

merge_base=$(git merge-base $baserev $headrev) ||
die "fatal: No commits in common between $base and $head"

# $head is the token given from the command line. If a ref with that
# name exists at the remote and their values match, we should use it.
# Otherwise find a ref that matches $headrev.
find_matching_ref='
	sub abbr {
		my $ref = shift;
		if ($ref =~ s|refs/heads/|| || $ref =~ s|refs/tags/||) {
			return $ref;
		} else {
			return $ref;
		}
	}

	my ($exact, $found);
	while (<STDIN>) {
		my ($sha1, $ref, $deref) = /^(\S+)\s+(\S+?)(\^\{\})?$/;
		next unless ($sha1 eq $ARGV[1]);
		$found = abbr($ref);
		if ($ref =~ m|/\Q$ARGV[0]\E$|) {
			$exact = $found;
			last;
		}
	}
	if ($exact) {
		print "$exact\n";
	} elsif ($found) {
		print "$found\n";
	}
'

ref=$(git ls-remote "$url" | perl -e "$find_matching_ref" "$head" "$headrev")

url=$(git ls-remote --get-url "$url")

git show -s --format='The following changes since commit %H:

  %s (%ci)

are available in the git repository at:
' $baserev &&
echo "  $url${ref+ $ref}" &&
git show -s --format='
for you to fetch changes up to %H:

  %s (%ci)

----------------------------------------------------------------' $headrev &&

if test -n "$branch_name"
then
	echo "(from the branch description for $branch_name local branch)"
	echo
	git config "branch.$branch_name.description"
fi &&

if test -n "$tag_name"
then
	git cat-file tag "$tag_name" |
	sed -n -e '1,/^$/d' -e '/^-----BEGIN PGP /q' -e p
	echo
fi &&

if test -n "$branch_name" || test -n "$tag_name"
then
	echo "----------------------------------------------------------------"
fi &&

git shortlog ^$baserev $headrev &&
git diff -M --stat --summary $patch $merge_base..$headrev || status=1

if test -z "$ref"
then
	echo "warn: No branch of $url is at:" >&2
	git show -s --format='warn:   %h: %s' $headrev >&2
	echo "warn: Are you sure you pushed '$head' there?" >&2
	status=1
fi
exit $status
