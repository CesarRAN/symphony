cachyos_latest() {
  local LC_ALL=C
  local cache_file="/tmp/cachyos_update_cache_${UID}"
  local cache_max_age=21600  # 6 horas

  local current_time boot_time cache_mtime cache_age use_cache=0
  current_time=$(date +%s)

  # --- Invalidar la caché después de reiniciar ---
  if [[ -r /proc/uptime ]]; then
    boot_time=$(( current_time - $(awk '{print int($1)}' /proc/uptime) ))
    cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || printf '0')
    if (( cache_mtime < boot_time )); then
      rm -f -- "$cache_file"
    fi
  fi

  # --- Información local del sistema ---
  local distro="CachyOS"
  local running_kernel kernel_pkg kernel_installed kernel_latest
  local cachy_repos last_upgrade reboot_needed=0

  if [[ -r /etc/os-release ]]; then
    distro=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/^"|"$/, "", $2); print $2; exit}' /etc/os-release)
    [[ -z "$distro" ]] && distro="CachyOS"
  fi

  running_kernel=$(uname -r)

  # En Arch/CachyOS, pkgbase identifica el paquete del kernel arrancado.
  if [[ -r "/usr/lib/modules/${running_kernel}/pkgbase" ]]; then
    kernel_pkg=$(<"/usr/lib/modules/${running_kernel}/pkgbase")
  else
    kernel_pkg=$(pacman -Qoq "/usr/lib/modules/${running_kernel}" 2>/dev/null | head -n 1)
  fi

  if [[ -n "$kernel_pkg" ]]; then
    kernel_installed=$(pacman -Q "$kernel_pkg" 2>/dev/null | awk '{print $2}')
  fi

  # Si el directorio de módulos del kernel arrancado ya no existe,
  # normalmente se actualizó el kernel y falta reiniciar.
  [[ ! -d "/usr/lib/modules/${running_kernel}" ]] && reboot_needed=1

  if command -v pacman-conf >/dev/null 2>&1; then
    cachy_repos=$(pacman-conf --repo-list 2>/dev/null \
      | grep -E '^cachyos($|-)' \
      | paste -sd ',' - | sed 's/,/, /g')
  else
    cachy_repos=$(awk '
      /^\[[^]]+\]$/ {
        repo=$0
        gsub(/^\[|\]$/, "", repo)
        if (repo ~ /^cachyos($|-)/) print repo
      }
    ' /etc/pacman.conf 2>/dev/null | paste -sd ',' - | sed 's/,/, /g')
  fi
  [[ -z "$cachy_repos" ]] && cachy_repos="no detectados"

  # Última actualización completa registrada por pacman.
  if [[ -r /var/log/pacman.log ]]; then
    last_upgrade=$(grep -E "\[PACMAN\] Running 'pacman .*-[^']*S[^']*u[^']*'" \
      /var/log/pacman.log 2>/dev/null \
      | tail -n 1 \
      | sed -E 's/^\[([^]]+)\].*/\1/')
  fi
  [[ -z "$last_upgrade" ]] && last_upgrade="no encontrada"

  # --- Comprobar la caché ---
  if [[ -f "$cache_file" ]]; then
    cache_age=$(( current_time - $(stat -c %Y "$cache_file") ))
    if (( cache_age >= 0 && cache_age < cache_max_age )); then
      use_cache=1
    fi
  fi

  local repo_count=0 repo_names="" repo_status="ok"
  local aur_count=0 aur_names="" aur_helper="" aur_status="disabled"

  if (( use_cache )); then
    repo_count=$(sed -n '1p' "$cache_file")
    repo_names=$(sed -n '2p' "$cache_file")
    repo_status=$(sed -n '3p' "$cache_file")
    aur_count=$(sed -n '4p' "$cache_file")
    aur_names=$(sed -n '5p' "$cache_file")
    aur_helper=$(sed -n '6p' "$cache_file")
    aur_status=$(sed -n '7p' "$cache_file")
    kernel_latest=$(sed -n '8p' "$cache_file")
  else
    local repo_updates="" repo_rc=0
    local aur_updates="" aur_rc=0

    # checkupdates usa una base separada: no ejecuta un pacman -Sy parcial.
    if command -v checkupdates >/dev/null 2>&1; then
      if repo_updates=$(timeout 45 checkupdates --nocolor 2>/dev/null); then
        repo_rc=0
      else
        repo_rc=$?
      fi

      case "$repo_rc" in
        0|2)
          repo_status="ok"
          ;;
        124)
          repo_status="timeout"
          repo_updates=""
          ;;
        *)
          repo_status="error"
          repo_updates=""
          ;;
      esac
    else
      repo_status="missing"
    fi

    if [[ -n "$repo_updates" ]]; then
      repo_count=$(printf '%s\n' "$repo_updates" | sed '/^[[:space:]]*$/d' | wc -l)
      repo_names=$(printf '%s\n' "$repo_updates" \
        | awk 'NF {print $1}' \
        | head -n 3 \
        | paste -sd ',' - | sed 's/,/, /g')

      if [[ -n "$kernel_pkg" ]]; then
        kernel_latest=$(printf '%s\n' "$repo_updates" \
          | awk -v pkg="$kernel_pkg" '$1 == pkg {print $4; exit}')
      fi
    fi
    [[ -z "$kernel_latest" ]] && kernel_latest="$kernel_installed"

    # AUR es opcional. Se usa el helper que ya esté instalado.
    if command -v paru >/dev/null 2>&1; then
      aur_helper="paru"
    elif command -v yay >/dev/null 2>&1; then
      aur_helper="yay"
    fi

    if [[ -n "$aur_helper" ]]; then
      aur_status="ok"
      if aur_updates=$(timeout 45 "$aur_helper" -Qua --color never 2>/dev/null); then
        aur_rc=0
      else
        aur_rc=$?
      fi

      if (( aur_rc == 124 )); then
        aur_status="timeout"
        aur_updates=""
      elif (( aur_rc != 0 )) && [[ -z "$aur_updates" ]]; then
        aur_status="error"
      fi

      if [[ -n "$aur_updates" ]]; then
        aur_count=$(printf '%s\n' "$aur_updates" | sed '/^[[:space:]]*$/d' | wc -l)
        aur_names=$(printf '%s\n' "$aur_updates" \
          | awk 'NF {print $1}' \
          | head -n 3 \
          | paste -sd ',' - | sed 's/,/, /g')
      fi
    fi

    printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
      "$repo_count" "$repo_names" "$repo_status" \
      "$aur_count" "$aur_names" "$aur_helper" "$aur_status" \
      "$kernel_latest" > "$cache_file"
  fi

  # Validar campos numéricos de una caché dañada o antigua.
  [[ "$repo_count" =~ ^[0-9]+$ ]] || repo_count=0
  [[ "$aur_count" =~ ^[0-9]+$ ]] || aur_count=0
  [[ -z "$kernel_latest" ]] && kernel_latest="$kernel_installed"

  # --- Colores ---
  local c1=$'\e[38;2;81;188;254m\e[1m'
  local c2=$'\e[38;2;105;181;254m\e[1m'
  local c3=$'\e[38;2;130;173;253m\e[1m'
  local c4=$'\e[38;2;154;166;253m\e[1m'
  local c5=$'\e[38;2;169;160;253m\e[1m'
  local c6=$'\e[38;2;179;154;253m\e[1m'
  local c7=$'\e[38;2;186;153;253m\e[1m'
  local c8=$'\e[38;2;192;163;253m\e[1m'
  local c9=$'\e[38;2;198;167;253m\e[1m'
  local c10=$'\e[38;2;205;173;252m\e[1m'
  local green=$'\e[1;38;2;171;255;74m'
  local yellow=$'\e[1;38;2;255;210;90m'
  local reset=$'\e[0m'
  local dim=$'\e[2;37m'
  local pad='                                               '

  # --- Panel ---
  printf '%s%s┌──────%s───────%s───────%s───────%s───────%s───────%s───────%s───────%s───────%s──────┐%s %sCachyOS Updates%s\n' \
     "$c1" "$c2" "$c3" "$c4" "$c5" "$c6" "$c7" "$c8" "$c9" "$c10" "$c10" "$reset" "$c1" "$reset"

  printf '%s%s├ 󰣇  System   %s  %s %s(rolling)%s\n' \
    "$pad" "$c2" "$reset" "$distro" "$dim" "$reset"

  printf '%s%s├ 󰻠  Running  %s  %s\n' \
    "$pad" "$c3" "$reset" "$running_kernel"

  if [[ -n "$kernel_pkg" && -n "$kernel_installed" ]]; then
    if [[ -n "$kernel_latest" && "$kernel_latest" != "$kernel_installed" ]]; then
      printf '%s%s├ 󰒔  Kernel   %s  %s %s→ %s%s\n' \
        "$pad" "$c4" "$reset" "$kernel_installed" "$green" "$kernel_latest" "$reset"
    else
      printf '%s%s├ 󰒔  Kernel   %s  %s  %sin sync%s\n' \
        "$pad" "$c4" "$reset" "$kernel_installed" "$c4" "$reset"
    fi
  fi

  printf '%s%s├ 󰏖  Repos    %s  %s\n' \
    "$pad" "$c5" "$reset" "$cachy_repos"

  case "$repo_status" in
    ok)
      if (( repo_count == 0 )); then
        printf '%s%s├ 󰏔  Official %s  0  %sup to date%s\n' \
          "$pad" "$c6" "$reset" "$c6" "$reset"
      else
        printf '%s%s├ 󰏔  Official %s  %s%d update(s)%s' \
          "$pad" "$c6" "$reset" "$green" "$repo_count" "$reset"
        [[ -n "$repo_names" ]] && printf '  %s(%s)%s' "$dim" "$repo_names" "$reset"
        printf '\n'
      fi
      ;;
    missing)
      printf '%s%s├ 󰏔  Official %s  %sinstall pacman-contrib%s\n' \
        "$pad" "$c6" "$reset" "$yellow" "$reset"
      ;;
    timeout)
      printf '%s%s├ 󰏔  Official %s  %scheck timed out%s\n' \
        "$pad" "$c6" "$reset" "$yellow" "$reset"
      ;;
    *)
      printf '%s%s├ 󰏔  Official %s  %scheck failed%s\n' \
        "$pad" "$c6" "$reset" "$yellow" "$reset"
      ;;
  esac

  if [[ -n "$aur_helper" ]]; then
    if [[ "$aur_status" == "ok" ]]; then
      if (( aur_count == 0 )); then
        printf '%s%s├ 󰮯  AUR      %s  0  %sup to date%s  %s(%s)%s\n' \
          "$pad" "$c7" "$reset" "$c7" "$reset" "$dim" "$aur_helper" "$reset"
      else
        printf '%s%s├ 󰮯  AUR      %s  %s%d update(s)%s' \
          "$pad" "$c7" "$reset" "$green" "$aur_count" "$reset"
        [[ -n "$aur_names" ]] && printf '  %s(%s)%s' "$dim" "$aur_names" "$reset"
        printf '\n'
      fi
    else
      printf '%s%s├ 󰮯  AUR      %s  %scheck unavailable%s  %s(%s)%s\n' \
        "$pad" "$c7" "$reset" "$yellow" "$reset" "$dim" "$aur_helper" "$reset"
    fi
  fi

  if (( reboot_needed )); then
    printf '%s%s├ 󰜉  Reboot   %s  %srecommended%s\n' \
      "$pad" "$c8" "$reset" "$yellow" "$reset"
  fi

  printf '%s%s├ 󰋚  Updated  %s  %s\n' \
    "$pad" "$c9" "$reset" "$last_upgrade"

  # --- Estado de caché ---
  if (( use_cache )); then
    local cache_hours cache_mins next_check next_hours next_mins next_time
    cache_age=$(( current_time - $(stat -c %Y "$cache_file") ))
    cache_hours=$(( cache_age / 3600 ))
    cache_mins=$(( (cache_age % 3600) / 60 ))
    next_check=$(( cache_max_age - cache_age ))
    next_hours=$(( next_check / 3600 ))
    next_mins=$(( (next_check % 3600) / 60 ))
    next_time=$(date -d "@$(( $(stat -c %Y "$cache_file") + cache_max_age ))" '+%H:%M')

    printf '%s%s├ 󰥔  Cached   %s  %dh %dm ago\n' \
      "$pad" "$c10" "$reset" "$cache_hours" "$cache_mins"
    printf '%s%s└ 󰁝  Next     %s  in %dh %dm  %s(after %s)%s\n' \
      "$pad" "$c10" "$reset" "$next_hours" "$next_mins" "$dim" "$next_time" "$reset"
  else
    printf '%s%s└ 󰁝  Checked  %s  just now\n' \
      "$pad" "$c10" "$reset"
  fi
}

cachyos_latest
