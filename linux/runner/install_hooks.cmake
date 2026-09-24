execute_process(
  COMMAND chmod +x "${CMAKE_INSTALL_PREFIX}/ordo.desktop"
)
execute_process(
  COMMAND gio set -t string "${CMAKE_INSTALL_PREFIX}/ordo" metadata::custom-icon "file://${CMAKE_INSTALL_PREFIX}/ordo.png"
  ERROR_QUIET
)
