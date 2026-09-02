#!/usr/bin/env bash
# No-reuse gate (port spec §1.3): the clean-room target must not reference
# the old iOS source directory or its symbols. Run from the repo root or
# from ios-web-port/.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
status=0

# 1. No path into the old target from the project definition or sources.
if grep -rn --include='*.yml' --include='*.swift' -E '(^|[^A-Za-z0-9_])\.\./ios/|"ios/HOney|/ios/HOney/' "$here/project.yml" "$here/HOneyNative" "$here/HOneyNativeTests" "$here/HOneyCore/Sources" "$here/HOneyCore/Tests"; then
  echo "no-reuse: a path into the old ios/ target was found" >&2
  status=1
fi

# 2. None of the old target's type names are compiled here.
old_symbols='AppModel|AppServices|SurfacePalette|SurfacePaletteSpec|PortalWebSessionBridge|PortalWebScreen|PortalWebController\.shared\.bridge|HOneyFileStorage|PublishedKeyRecoveryStore|OwnershipKeyStoring\b.*legacy|ExperienceTargetRepository|NextLessonRepository|HistoryRepository|MainTabView|BrandWordmarkPlaceholder|SchoolReconnectView|ImportConsentView|CommunityMeaningView|InteractiveExperienceRow|AppLoadingState|AppEmptyState|AppBanner\b|AppSectionHeader|PrimaryActionButtonStyle|SecondaryActionButtonStyle'
if grep -rn --include='*.swift' -E "\b($old_symbols)\b" "$here/HOneyNative" "$here/HOneyNativeTests" "$here/HOneyCore/Sources" "$here/HOneyCore/Tests"; then
  echo "no-reuse: an old iOS target symbol name appears in the clean-room sources" >&2
  status=1
fi

# 3. The old target's files are not symlinked or copied in.
if find "$here/HOneyNative" "$here/HOneyCore" -path '*/.build' -prune -o -type l -print | grep -q .; then
  echo "no-reuse: symlinks are not allowed in the clean-room target" >&2
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "no-reuse: clean"
fi
exit "$status"
