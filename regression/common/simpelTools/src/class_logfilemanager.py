import uuid, time
from common.simpelTools.src.filetools import *
from common.simpelTools.src.platform_detect import platform_deliver
import json


class LogfileManager:
    """
    Class manages log files and maintain the folder hierarchy
    """

    def __init__(self, path_to_logfiles):
        """
        path /home/user/project_root/ must exist,
        /logfiles may exist
        :param path_to_logfiles: /home/user/project_root/logfiles
        """
        logfiles_subfolder_tmporary = 'logs_last_run'  # last run logs
        logfiles_zipped = 'logs_final_zip'
        logfiles_working = 'logs_working_dir'
        self.name_constant_part = 'logfiles'

        parent_directory = os.path.dirname(path_to_logfiles)
        if not os.path.exists(parent_directory):
            raise(BaseException(("location for logfile does not exist!", path_to_logfiles)))

        self.gPath_logfile_folder = path_to_logfiles
        self.path_abs_logfiles_temporary = os.path.join(self.gPath_logfile_folder, logfiles_subfolder_tmporary)
        self.path_abs_logfiles_zipped = os.path.join(self.gPath_logfile_folder, logfiles_zipped)
        self.path_abs_logfiles_working= os.path.join(self.gPath_logfile_folder, logfiles_working)
        l.info("logfiles tmp:  %s"% self.path_abs_logfiles_temporary)
        l.info("logfiles zip:  %s"%self.path_abs_logfiles_zipped)
        l.info("logfiles work: %s"%self.path_abs_logfiles_working)

        self.logfiles_manage_init()

        # todo: make this nicer.
        self.unique_log_index = 0  # used to actually make every generated archive unique



    def get_dir_tmp_logfiles(self):
        return self.path_abs_logfiles_temporary

    def get_dir_zip_logfiles(self):
        return self.path_abs_logfiles_zipped

    def get_dir_work(self):
        return self.path_abs_logfiles_working

    def logfiles_manage_init(self):
        mkdirSkipExistence(self.gPath_logfile_folder, 'root_folder_logfiles')
        self.zipfolder_reset_create()
        self.logfiles_folder_reset_create()

    def logfiles_folder_reset_create(self):
        """
        Remove old logfiles from folder
        todo: there is a shutil function removing a whole tree. (removeFolderTree(rootFolderToBeRemoved))
        :return:
        """

        reset = [self.path_abs_logfiles_temporary, self.path_abs_logfiles_working]
        self.reset_folders(reset)

        # todo: this should be something lead to an upload folder. (also sowas wie nen zwischnstand. braucht man das eignentlich?
        #  - 1. collect all final packaes
        #  - 2. folder where files beeing uploaded from
        # mkdirSkipExistence(self.path_abs_logfiles_zipped) may not be cleared! killes upload!

    def zipfolder_reset_create(self):
        self.reset_folders([self.path_abs_logfiles_zipped])

    def reset_folders(self, reset):
        """
        Clear all files in a folder,
        create folder if it does not existing,
        leave empty but created folder behind.
        :param reset: an array of path names for folders to be resetted
        :return:
        """
        for old_folder in reset:
            tmp_base = os.path.dirname(old_folder)
            if not tmp_base :
                l.error("basefolder %s does not exist, it's the ancor for logfiles: %s" % tmp_base )
            if not os.path.isdir(old_folder):
                l.info("created logfile folder %s" % old_folder)
                mkdirSkipExistence(old_folder)
                continue
            l.info("[log]: check folder %s" % old_folder)
            try:
                tmp_old_files = os.listdir(old_folder)
            except BaseException as e:
                l.info("No folder found => nothing to reset! %s" % e)
                continue
            if tmp_old_files:
                for f in tmp_old_files:
                    l.info("remove old file: %s" % f)
                    try:
                        os.remove(os.path.join(old_folder, f))
                    except BaseException as e:
                        l.info(e)

    def archive_logs(self, logfile_suffix, logfile_preafix=''):
        """
        compresses all logfiles from the source folder and compresses them to the target folder.
        :param logfile_preafix: optinal name leading zip-file name, like UUID, index etc
        :param logfile_suffix: mandatory name ending zip-file name, like the test name just now done
        """
        # generate path
        tmp_logfile_name = "%s%s_%s" % (logfile_preafix, self.name_constant_part, logfile_suffix)
        path_logfile_archive = os.path.join(self.path_abs_logfiles_zipped, tmp_logfile_name)

        folder_source = self.path_abs_logfiles_temporary

        # compressing...
        logfiles_extension = 'zip'
        if os.path.exists(folder_source):
            assumed_zip_file_name = "%s.%s"% (path_logfile_archive, logfiles_extension)
            if os.path.exists(assumed_zip_file_name):
                raise(BaseException("File exists, will not compress, will abort! >%s<" % assumed_zip_file_name))
            else:
                l.info('Compress to archive: %s' % tmp_logfile_name)
                l.info("Compressing logfiles to %s.%s)" %(path_logfile_archive,logfiles_extension))
                # remove files which a zipped, when no error occured during compressing!
                try:
                    shutil.make_archive(path_logfile_archive, logfiles_extension, folder_source)
                except BaseException as e:
                    l.error("Compressing files from %s to %s failed" % (folder_source, path_logfile_archive))
                    l.error("Reason: >%s<" % e)
        else:
            l.error("Path to logfiles does not exist, cant archive logfiles! %s" % folder_source)
        return tmp_logfile_name

    def get_unique_index(self):
        """
        Inc index after returned
        :return: index, inc afterwards
        """
        ret = self.unique_log_index
        self.unique_log_index += 1
        return ret

    def wrap_archive_logs_and_clear(self, uuid, test_name='', upper_index=0, comment="x", result=None):
        """
        Special function for flasher test. Provided is an external uuid and a test name, which can be leaved blank.
        the upper index is some index which is maintained by the upper programm, like a chapter. this function adds an
        auto incrementing counter to it. just in case, you run this function twice in a "single" test / do not
        want to manage the logfile names, just have them uniqe.
        :param uuid: a uuid provided by the overlaying test. like the pirate
        :param test_name: test name, something like Flasher Test 55
        :param upper_index: Upper index from test framework, treated like major index, minor is a ever incementing one
        :return: nothing (compressing a file)
        """
        #generate a proper name for logfiles
        tmp_name_logfiles = self.gen_name_logfiles_man(
            has_uuid=uuid,
            index_maj=upper_index,
            index_minor=self.get_unique_index()
        )

        #returns total name, will be used to write a jsonfile with the result array beside it.
        total_name = self.archive_logs(logfile_suffix="%s_%s" % (test_name, comment), logfile_preafix=tmp_name_logfiles)

        summary_json = os.path.join(self.path_abs_logfiles_zipped, "%s.json" % total_name)
        if result is not None:
            result = result[-1]
            dict_result = {
                           'Name_Test': result[2],
                           'num_sub_tests': result[3],  # uuid err name num_test flash_name
                           'result': result[1], # number failed tests. Expected 0
                           'Tesdescription': total_name,
                           'uuid': uuid,
                           }
        else:
            dict_result = {
                "num_err": "Not provided",
                'Tesdescription': total_name
            }

        with open(summary_json, 'w') as json_file:
            json.dump(dict_result, json_file, indent=4)
        # reset logfile folder
        self.logfiles_folder_reset_create()

    @classmethod
    def gen_name_logfiles_man(cls, additional=None, xos=None,index_maj=0, index_minor=0, has_uuid=None):
        """
        Generateing a probably short and unique name of for logfiles. The Additional parameter can be used to
        pass something like netX, port or the stream into the file name.
        If you have a special UUID for your test, set the param has_uuid="my_special_one" to it.
        :param additional: an array of additional strings like netX type or so on
        :param xos: a dictionary representing the OS-structure. This is generated from the flasher test.
        :param has_uuid: A optional parameter. If not set a default ID is generated.
        :return: a generated name for a file without any extension.
        """

        #todo: maybe put the index in the parts sectiion and simply expect them to be in the right format!
        if not has_uuid:
            strip_uuid = cls.gen_stripped_uuid()
        else:
            strip_uuid = has_uuid

        time_stamp = cls.gen_timestamp()
        os_string = cls.gen_os_string(xos)
        # think something about timestamp...
        prefix = "%s-%02d_%02d-%s-%s" % (strip_uuid, index_maj, index_minor, time_stamp, os_string)
        if additional:
            # append elements from suffix
            for ele in additional:
                prefix = "%s-%s" % (prefix, ele)
        return prefix

    @classmethod
    def gen_os_string(cls,inherit_os=None):

        if inherit_os:
            xos = inherit_os
        else:
            xos = platform_deliver()

        # todo: add linux version like here
        #if :
        #    name_logfile_archive = 'log_%s_%02d_%02d_%s_%s_%s' % (self.uuid_test,self.iteration_index,self.logfile_index, self.__class__.__name__,  vLinux, cTheMachine)
        #else:
        #    name_logfile_archive = 'log_%s_%02d_%02d_%s_%s' % (self.uuid_test,self.iteration_index,self.logfile_index, self.__class__.__name__,  cTheMachine)


        os_string = "%s-%s" % (xos[u'os_cThePlatform'], xos[u'os_cTheMachine'])
        return os_string

    @classmethod
    def gen_timestamp(cls):
        time_stamp = time.strftime("%Y%m%d_%H%M%S", time.gmtime())
        return time_stamp

    @classmethod
    def gen_stripped_uuid(cls):
        tmp_uuid = uuid.uuid4()
        strip_together = tmp_uuid.hex[16:24]  # variant bits and begin of node ID
        return strip_together


if __name__ == '__main__':
    lfm = LogfileManager("/tmp/logfiles")
    test_log_file = os.path.join('%s/demofile.log'%lfm.get_dir_tmp_logfiles())

    f = open(test_log_file, "wb")
    f.write("A test log")
    f.close()

    lfm.wrap_archive_logs_and_clear("1234testUUID", 'awesome_test', 43)
    lfm.wrap_archive_logs_and_clear("1234testUUID", 'awesome_test', 44)


    exit()


    lfm.archive_logs("mySuffix","MyPreafix1")
    print("stringname")
    print(LogfileManager.gen_name_logfiles_man())
    print(LogfileManager.gen_name_logfiles_man(['netX', 'strerr']))

    # test archive logs:
    lfm.archive_logs(lfm.gen_name_logfiles_man(has_uuid='myUUID',additional=['meinNetX','port']))


