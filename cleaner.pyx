# cython: language_level=3
import os, shutil, psutil, ctypes, winreg
from os.path import exists, isdir, join
from webbrowser import open as web_open

cpdef kill_processes(process_names):
    for proc in psutil.process_iter(['pid', 'name']):
        if proc.info['name'] in process_names:
            try:
                os.kill(proc.info['pid'], 9)
                print(f"Killed: {proc.info['name']} (PID {proc.info['pid']})")
            except Exception as e:
                print(f"Error killing {proc.info['name']}: {e}")

cpdef str get_gamecenter_path(str protocol):
    cdef str key_path = fr"{protocol}\shell\open\command"
    try:
        key = winreg.OpenKey(winreg.HKEY_CLASSES_ROOT, key_path)
        command, regtype = winreg.QueryValueEx(key, None)
        winreg.CloseKey(key)
    except Exception:
        return ""
    
    parts = command.split('"')
    cdef str exe_path
    if len(parts) > 1:
        exe_path = parts[1]
    else:
        exe_path = command.strip()
    
    cdef str dir_path = os.path.dirname(exe_path)
    if not dir_path.endswith(os.sep):
        dir_path += os.sep
    return dir_path

cpdef str get_download_path_from_ini(str base_path):
    cdef str ini_path = os.path.join(base_path, "GameCenter.ini")
    cdef bint in_main = False
    try:
        with open(ini_path, "r", encoding="utf-16") as f:
            for line in f:
                line = line.strip()
                if line.startswith("[") and line.endswith("]"):
                    if line.lower() == "[main]":
                        in_main = True
                    else:
                        if in_main:
                            break
                elif in_main and line.startswith("DownloadPath="):
                    return line[len("DownloadPath="):].strip()
    except Exception as e:
        print(f"Error reading {ini_path}: {e}")
    return ""

cpdef str parse_game_path():
    web_open("mailrugames://play/0.1177", new=2)
    cdef int pid = 0
    while pid == 0:
        for process in psutil.process_iter():
            try:
                if process.name() == "Game.exe":
                    pid = process.pid
                    break
            except Exception:
                pass

    cdef list cmd_list = psutil.Process(pid=pid).cmdline()
    if not cmd_list:
        return ""
    cdef str exe_path = os.path.normpath(cmd_list[0])
    cdef list parts = exe_path.split(os.sep)
    cdef list filtered_parts = [part for part in parts if part.lower() not in ("bin64release", "game.exe")]
    
    cdef str new_path = ""
    if filtered_parts:
        if filtered_parts[0].endswith(":"):
            if len(filtered_parts) > 1:
                new_path = filtered_parts[0] + os.sep + os.path.join(*filtered_parts[1:])
            else:
                new_path = filtered_parts[0] + os.sep
        else:
            new_path = os.path.join(*filtered_parts)
    return new_path

cpdef str get_username():
    cdef str username = os.environ.get("USERNAME", "")
    if not username:
        username = os.path.basename(os.path.expanduser("~"))
    return username

cpdef delete_path(str path):
    if not exists(path):
        print(f"Not found: {path}")
        return
    try:
        if isdir(path):
            shutil.rmtree(path, ignore_errors=True)
            kind = "folder"
        else:
            os.remove(path)
            kind = "file"
        print(f"Deleted {kind}: {path}")
    except Exception as e:
        print(f"Error deleting {path}: {e}")

cpdef clean_temp():
    for d in (os.getenv('TEMP'), r"C:\Windows\Temp"):
        if d and exists(d):
            try:
                for entry in os.listdir(d):
                    p = join(d, entry)
                    if isdir(p):
                        shutil.rmtree(p, ignore_errors=True)
                    else:
                        try:
                            os.remove(p)
                        except Exception:
                            pass
                print(f"Cleaned: {d}")
            except Exception as e:
                print(f"Error cleaning {d}: {e}")
        else:
            print(f"Temp folder not found: {d}")

cpdef main():
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("Administrator privileges required.")
        return
    gc = get_gamecenter_path("vkplay")
    updates = get_download_path_from_ini(gc)
    client = parse_game_path()
    username = get_username()
    kill_processes(["Game.exe", "GameCenter.exe"])
    delete_path(fr"C:\Users\{username}\Saved Games\My Games\Warface")
    delete_path(updates + r"packages\warface")
    delete_path(join(client, "Game.log"))
    delete_path(join(client, "LogBackups"))
    clean_temp()
    input("Press Enter to quit ")

if __name__ == "__main__":
    main()
