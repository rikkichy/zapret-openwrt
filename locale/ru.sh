# Russian translations for service.sh
# Each T_<key> is a translatable string. service.sh's t() looks them up.
# Some strings contain printf placeholders (%s, %d) — preserve them when translating.

# ---- main menu ----
T_menu_title="ZAPRET DISCORD+YOUTUBE — МЕНЕДЖЕР"
T_sec_strategy=":: СТРАТЕГИЯ"
T_sec_service=":: СЛУЖБА"
T_sec_lists=":: СПИСКИ"
T_sec_tools=":: ИНСТРУМЕНТЫ"
T_m_install="Установить стратегию"
T_m_show_active="Показать активную стратегию"
T_m_start="Запустить zapret"
T_m_stop="Остановить zapret"
T_m_restart="Перезапустить zapret"
T_m_status="Проверить статус"
T_m_lists="Редактировать списки доменов"
T_m_diag="Диагностика"
T_m_uninstall="Удалить zapret-openwrt"
T_m_exit="Выход"
T_select_option="Выберите пункт (0-9): "
T_active="активна"

# ---- base zapret install ----
T_base_missing="Базовый zapret не установлен."
T_base_install_q="Установить zapret %s от bol-van/zapret? [Y/n]: "
T_base_install_skip="Пропущено. Установите вручную: %s"
T_base_install_fail="Установка zapret не завершилась"
T_base_downloading="Скачиваю zapret %s (openwrt-embedded)..."
T_base_download_fail="Скачивание не удалось (нужен uclient-fetch/curl/wget; проверьте сеть)"
T_extracting="Распаковка..."
T_extract_fail="Распаковка не удалась"
T_running_installer="Запускаю install_easy.sh (спросит про IPv6, режим, firewall и т.д.)"
T_installer_failed="install_easy.sh завершился с ошибкой"
T_base_installed="Базовый zapret установлен"
T_stopping_pre_setup="Останавливаю zapret (запущен install_easy.sh) перед мастером настройки..."

# ---- first-time setup ----
T_first_setup="ПЕРВОНАЧАЛЬНАЯ НАСТРОЙКА"
T_no_strategy_yet="Стратегия discord-youtube не обнаружена."
T_run_setup_q="Запустить мастер настройки? (Y/n): "
T_step1="Шаг 1/3: Копирую списки доменов..."
T_step2="Шаг 2/3: Копирую файлы фейковых пакетов..."
T_step3="Шаг 3/3: Выберите стратегию для установки"
T_tip_strategy="Совет: начните с #1 (general). Сменить можно позже."
T_select_strategy="Выберите стратегию (1-%d): "
T_start_now_q="Запустить zapret сейчас? (Y/n): "
T_starting="Запускаю zapret..."
T_done="Готово"
T_skipped_strategy="Установка стратегии пропущена. Выберите пункт меню 1 позже."

# ---- uninstall ----
T_uninstall_title="УДАЛЕНИЕ zapret-openwrt"
T_uninstall_will="Действия:"
T_uninstall_stop="  - Остановить службу zapret"
T_uninstall_wipe="  - Удалить /tmp/zapret-openwrt (каталог скриптов)"
T_uninstall_warn="/opt/zapret и стратегии в custom.d/ затронуты НЕ БУДУТ."
T_uninstall_proceed="Продолжить? (y/N): "
T_cancelled="Отменено."
T_stopping="Останавливаю zapret..."
T_stopped="Остановлено"
T_no_init="Init-система не обнаружена; пропускаю остановку службы"
T_removing="Удаляю /tmp/zapret-openwrt..."
T_removed="Удалено"
T_nothing_remove="/tmp/zapret-openwrt отсутствует (удалять нечего)"
T_uninstall_done="Удаление завершено. Выход."

# ---- command registration ----
T_cmd_registering="Регистрирую команду 'zapret'..."
T_cmd_registered="Готово — вводите 'zapret' для запуска меню в любой момент"
T_cmd_register_fail="Не удалось зарегистрировать команду 'zapret' (нужны права root / запись в /usr/bin и /usr/lib)"

# ---- uninstall extras ----
T_uninstall_unlink="  - Удалить ссылку /usr/bin/zapret и /usr/lib/zapret-openwrt"
T_path_removed_fmt="Удалено: %s"

# ---- common ----
T_press_enter="Нажмите Enter для продолжения..."
T_no_zapret_base="ZAPRET_BASE не найден! zapret установлен?"
