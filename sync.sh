#!/bin/bash
# Синхронізація з GitHub (dankordigital/sidekick): забирає зміни сина,
# комітить локальні правки і пушить. На хостинг нічого не вантажить.
#
#   ./sync.sh                    — показує зміни, питає опис коміту і підтвердження
#   ./sync.sh "Опис змін"        — те саме, з готовим описом коміту
#
# Кожен push запускає на GitHub збірку застосунку (build.yml) — це нормально.

set -euo pipefail

cd "$(dirname "$0")"

BRANCH="$(git branch --show-current)"
if [ -z "$BRANCH" ]; then
  echo "Не на гілці (detached HEAD або незавершений rebase). Перевір: git status"
  exit 1
fi

# Основну гілку перейменовано на GitHub (15.10.2026): -8ilytw → -main.
# Стара назва на GitHub зникає, тож локальна гілка перейменовується сама.
OLD_BRANCH="claude/sidekick-app-architecture-8ilytw"
NEW_BRANCH="claude/sidekick-app-architecture-main"
if [ "$BRANCH" = "$OLD_BRANCH" ] && git ls-remote --exit-code --heads origin "$NEW_BRANCH" >/dev/null 2>&1; then
  echo "Гілку на GitHub перейменовано, перейменовую і тут: $NEW_BRANCH"
  git fetch -q --prune origin
  git branch -m "$OLD_BRANCH" "$NEW_BRANCH"
  git branch -q -u "origin/$NEW_BRANCH" "$NEW_BRANCH"
  git remote set-head origin -a >/dev/null 2>&1 || true
  BRANCH="$NEW_BRANCH"
fi

# 1. Забрати свіже з GitHub. Локальні незакомічені правки тимчасово відкладаються
#    і повертаються зверху (--autostash), наші коміти стають після комітів сина (--rebase).
echo "Забираю зміни з GitHub ($BRANCH) ..."
if ! git pull --rebase --autostash -q origin "$BRANCH"; then
  echo
  echo "Конфлікт: ти і син змінили ті самі рядки. Нічого не запушено."
  echo "Покажи це Claude або виріши вручну (git status), потім запусти ./sync.sh знову."
  exit 1
fi
# Відкладені правки могли не лягти назад чисто (той самий файл змінив син)
if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
  echo
  echo "Твої незакомічені правки конфліктують зі змінами сина. Нічого не запушено."
  echo "Файли з конфліктом:"
  git diff --name-only --diff-filter=U | sed 's/^/  ! /'
  echo "Покажи це Claude або виріши вручну, потім запусти ./sync.sh знову."
  exit 1
fi

# 2. Закомітити локальні правки, якщо є
if [ -n "$(git status --porcelain)" ]; then
  echo
  echo "Локальні зміни:"
  git status --short
  echo
  MSG="${1:-}"
  if [ -z "$MSG" ]; then
    read -r -p "Опис змін (для історії): " MSG
  fi
  [ -n "$MSG" ] || { echo "Порожній опис — скасовано."; exit 1; }
  read -r -p "Закомітити і відправити на GitHub? [y/N] " answer
  [ "$answer" = "y" ] || [ "$answer" = "Y" ] || { echo "Скасовано. Зміни лишились локально."; exit 0; }
  git add -A
  git commit -q -m "$MSG"
fi

# 3. Відправити, якщо є що
AHEAD="$(git rev-list --count "origin/$BRANCH..HEAD")"
if [ "$AHEAD" = "0" ]; then
  echo "Все синхронізовано, відправляти нічого."
  exit 0
fi

echo
echo "Відправляю на GitHub ($AHEAD коміт(ів)):"
git log --oneline "origin/$BRANCH..HEAD"
git push -q origin "$BRANCH"
echo "Готово → https://github.com/dankordigital/sidekick/commits/$BRANCH"
