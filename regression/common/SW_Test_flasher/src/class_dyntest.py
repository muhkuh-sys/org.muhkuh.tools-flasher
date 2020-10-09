import sys, os
from abc import abstractmethod
import uuid
import shutil

file_dir = os.path.dirname(os.path.realpath(__file__))  # xxx/src/
base_root = os.path.dirname(file_dir)  # location where all projects reside

print("dyntest bast path %s"%base_root)
sys.path.append(base_root)


from common.simpelTools.src.command_carrier import command_carrier, batch_command_base, eval_batch_result, slugify
from common.simpelTools.src.filetools import *
from common.simpelTools.src.class_logfilemanager import LogfileManager
from common.simpelTools.src.platform_detect import *
# todo: write batch command base into class off comman carrier, e.g. write a class "command_crrier"


# todo: monday compose tests
#  -loop
#  - detect netX, import from Framework
#  -detect-netX + json-routines (keep them in separate to keep them reuseable)
#  -maybe have a look at the python 3 standard fo os-detect, etc
#  -double check the command carrier with python 3
#  -generate 3.8 environment?
# todo: implement the json file script-handling
# todo: general parates to pass
# todo: Set input / output file for generation etc.
#  build in binary file match
#  find os-dependend build path from flasher relativ to file location
#  - result as a json document, stating with a dictionary
## later totos:
#   - logfiles are archived together with all other tests at the end.
#    - subfolder with enumerator and cclassname for every run
#    - Probably total result log?
#    - Log in json? put logfile path into json?
#    - think at managing UUID's


print(sys.executable)
print(sys.version)


class Dyntest:
    """
    todo: set UUID from the outside world
    todo: inherit logfile manager from external instance, or create own. temporarly logfile support removed from class and integrated in upper logfile manager.

    Behaviour:
    create object, "prepare", run the test, leave the test result as the purpose of this class.
    not intended to repeat a single step. only intended to encapsulate the tests and make them more readable!

    Note:
        Do not include the `self` parameter in the ``Args`` section.

    Args:
        msg (str): Human readable string describing the exception.
        code (:obj:`int`, optional): Error code.

    Attributes:
        testresult (dict): Tracing of test results
        path_folder_test_env (string): A working directory for test binaries
    """

    additional_info_to_logfile = ""     # some logfile info more

    # around test config
    # testintensety = 'quick'

    # generated psth
    path_folder_test_env = None
    numErrors = 0
    numErrors_a = []
    uuid_test = ""
    # todo: move to this to logfile manager
    iteration_index = 0 # index of class, for every new test, there should be an increment (done from extern unit test)

    def __init__(self, lfm_instance=None):

        assert lfm_instance  # todo: alter remove and gen auto-gen. but for now ist should crash if log is overwritten!
        self.lfm = lfm_instance  # type: LogfileManager
        self.logfile_prefix = ""  # for normal the UUID of he test
        self.last_comment = ""  # comment for next zip-archie, attached to the end. used for a memory name
        pass

    def set_last_comment(self, value):
        self.last_comment = slugify(value)

    def get_last_comment_rease(self):
        ret = self.last_comment
        self.last_comment = ""
        return ret

    @classmethod
    def set_random_uuid(cls):
        """
        Gen stripped UUID
        """
        cls.uuid_test = uuid.uuid4().hex[16:24]  # variant bits and begin of node ID

    @abstractmethod
    def run_test(self):
        pass

    @abstractmethod
    def pre_test_step(self):
        """
        sets up test environment. probably generating binary files etc.
        :return: nothing
        """
        # todo: probably move down
        pass

    def archive_logs(self):
        l.info("archiving logs")
        self.lfm.wrap_archive_logs_and_clear(
            self.uuid_test,
            self.__class__.__name__,
            self.get_iteration_index_inc(),
            comment=self.get_last_comment_rease(),
            result=self.numErrors_a
        )


    def get_iteration_index_inc(self):
        ret =  self.iteration_index
        self.iteration_index += 1
        return ret


class Flashertest(Dyntest):
    """
    Basic Flashtest
    don't know if this class is necessary or just useful for herachical stageing.
    maybe this is the collectionmechanisem for the results? Argparse etc?
    """

    bool_params_init = False
    plugin_name = None
    bus_port_parameters_flasher = None
    flasher_binary = None
    path_lua_files = None

    # Handling command path
    command_structure = None  # representing parameters

    def __init__(self, lfm):
        Dyntest.__init__(self, lfm)
        self.test_binary_size = None
        self.command_strings = []  # strings generated from command array abouve
        self.bool_interrupt_batch_f = False

    def run_test(self):
        l.info("# run %s with uuid: %s" % (self.__class__.__name__, self.uuid_test))
        assert self.bool_params_init
        self.pre_test_step()
        self.init_command_array()
        self.convert_final_command_entries_to_commands()
        self.run_batch_commands()
        self.archive_logs()

        l.info("# finished %s with uuid: %s" % (self.__class__.__name__, self.uuid_test))
        l.info("# Return for PyCharm")


    def init_params(self, plugin_name, memory_to_test, test_binary_size, path_lua_files, flasher_binary, dict_add_params):

        # todo: should be more a temporary solution for debugging, not for testing
        # todo: use output from jasonixer here!

        self.bus_port_parameters_flasher = "-b %s -u %s -cs %s" % (memory_to_test["b"], memory_to_test["u"], memory_to_test["cs"])

        # test binary size has to be smaller or equal to the physically available size
        if test_binary_size <= memory_to_test["size"]:
            self.test_binary_size = test_binary_size
        else:
            self.test_binary_size = memory_to_test["size"]

        self.init_params_global(plugin_name, path_lua_files, flasher_binary, dict_add_params)

    def init_params_global(self, plugin_name, path_lua_files, flasher_binary, dict_add_params):
        self.plugin_name = "-p %s" % plugin_name["plugin_name"]
        self.flasher_binary = flasher_binary
        self.path_lua_files = path_lua_files
        self.bool_params_init = True
        self.dict_add_params = dict_add_params

    @abstractmethod
    def init_command_array(self):
        """
        the command array is the part of a sub sub class which makes the difference.
        So every class has to care for it on its own. will set: command_structure
        """
        pass

    @abstractmethod
    def pre_test_step(self):
        """
        Must be executed before "init_command_array()"
        :return:
        """
        raise NotImplementedError('Please provide a preparation method for class >%s<, even if it is "pass"!' %
                                  self.__class__.__name__)

    # def convert_final_command_entries_to_commands(self):
    #     if self.command_strings:
    #         assert True
    #
    #     l.info("Generate commands:")
    #     for idx, ele in enumerate(self.command_structure):
    #
    #         # make full file path
    #         tmp_full_file_path = os.path.join(self.path_lua_files, ele[0])
    #         self.command_structure[idx][0] = tmp_full_file_path
    #         # concat all to one string
    #         tmp_final_test_command = self.flasher_binary
    #         for int_ele in ele:
    #             tmp_final_test_command += " %s" % int_ele
    #         # append
    #         self.command_strings.append(tmp_final_test_command)
    #         #todo: later: this should be also a json tolerant structure, combining input and output.
    #         l.info(self.command_strings[-1])

    def verify_version_of_flasher(self, mandatory_version, version_string):
        """
        netX Flasher v1.6.0_RC2 2019-November-01-T15:21
            GITv1.6.0_RC2-0-g0d3fca292224

        command: ./lua5.1.sh cli_flash.lua -version
        If every entry from array mandatory_version is in version_string, then this returns true,
        otherwise it raises the error.

        For this eature nothing else is implemented.

        :return:
        """

        #important, you iterate oer chars and they will propably match, but you are supposed to iterate over strings.
        assert type(mandatory_version) is not list
        # todo: this test is weak,










    def convert_final_command_entries_to_commands(self):
        if self.command_strings:
            assert True

        # define positions inside command_structure list
        prog_select = 0      # used to select the program, which should be executed
        parameter_start = 1  # first optional parameter for the program

        l.info("Generate commands:")
        for idx, ele in enumerate(self.command_structure):

            #detect the program to use
            dict_prog_select = ele[prog_select] # type = dict
            assert(type(dict_prog_select) is dict)
            tmp_final_test_command = None
            for prog in dict_prog_select.iterkeys():
                if prog == "flasher":
                    # concat all to one string
                    tmp_final_test_command = self.flasher_binary
                    # make full file path
                    tmp_full_file_path = os.path.join(self.path_lua_files, ele[parameter_start])
                    self.command_structure[idx][parameter_start] = tmp_full_file_path

                elif prog == "openocd":
                    # concat all to one string
                    tmp_final_test_command = dict_prog_select["bin_path"]
                elif prog == "bin_path":
                    # skip known parameter used for path to binary
                    pass
                else:
                    l.error("key %s is not supported" % prog)


            for int_ele in ele[parameter_start:]:
                tmp_final_test_command += " %s" % int_ele
            # append
            self.command_strings.append(tmp_final_test_command)
            #todo: later: this should be also a json tolerant structure, combining input and output.
            l.info(self.command_strings[-1])

    def run_batch_commands(self):
        default_carrier = command_carrier()
        default_carrier.bool_interrupt_batch = self.bool_interrupt_batch_f

        default_carrier.change_dir_to_bin = True  # relevant for executing flasher with linux correct
        l.info("Execute generated commands above!")
        # todo: rework the command carrier, this is kind of not cool. (redundant code)
        # inert here final commands!
        # todo: integrate the logfiles more?
        carrier_result = batch_command_base(
            default_carrier,
            self.command_strings,
            self.lfm.get_dir_tmp_logfiles(),
            self.uuid_test)
        self.numErrors += eval_batch_result(
            carrier_result,
            self.lfm.get_dir_tmp_logfiles(),
            self.logfile_prefix,
            "%s %s" % (self.uuid_test, self.__class__.__name__))
        self.numErrors_a.append([self.uuid_test, self.numErrors, self.__class__.__name__, len(self.command_strings)])

    @abstractmethod
    def check_additional_command(self):
        """
        Command for checking the binary files for example
        :return:
        """
        pass

