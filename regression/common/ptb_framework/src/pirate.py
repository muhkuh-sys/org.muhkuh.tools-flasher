import os

from common.simpelTools.src.platform_detect import platform_deliver
from common.simpelTools.src.class_logfilemanager import LogfileManager


class PTBEnv:
    # logfiles

    def __init__(self, path_to_logfiles_folder):
        self.os = platform_deliver()
        self.lfm = LogfileManager(path_to_logfiles_folder)  # manages all the logfiles
        file_dir = os.path.dirname(os.path.realpath(__file__))  # xxx/src/
        project_root_path = os.path.dirname(file_dir)  # xxx/helper_platform_detect
        self.base_root = os.path.dirname(project_root_path)  # location where all projects reside

        pass





