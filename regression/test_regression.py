import os
import sys
import unittest

from os.path import realpath, dirname

#import HtmlTestRunner

file_dir = os.path.dirname(os.path.realpath(__file__))  # xxx/src/
# project_root_path = os.path.dirname(os.path.dirname(file_dir))  # xxx/helper_platform_detect
regression_root = os.path.join(file_dir, "ptb_api")
sys.path.append(regression_root)

package_root = os.path.abspath(os.path.join(file_dir, '..', '..'))
sys.path.append(package_root)

# todo: dyntst may be out of date, redirect it!
# from ptb_api.SW_Test_flasher.src.class_dyntest import *
print(sys.path)
from SW_Test_flasher.src.class_dyntest import *

# import of tests
from NXTFLASHER_51.tc_nxtflasher_51 import NxtFlasher_51
from FLT_STANDARD.tc_flt_standard import FltStandardSqiFlash, FltStandardOtherFlash, FltTestcliSqiFlash
from FLT_HASH.tc_flt_hash import FltHash
from NXTFLASHER_55.tc_nxtflasher_55 import NxtFlasher_55
from WFP.wfp_test import TestWfp
# ptb imports
from ptb_framework.src.env_flasher import *


class UnitTestFlasherTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        """
        old!
        moved to official flasher repository into dev-branch.
        also some simple tools moved as a copy and the ptb_abi-folder
        Die api nutzt den ptb_api ordner von der org.flasher Umgebung und die tstumgebung nutzt derzeit noch den
        globalen ordner. daruber musste man sich auch in Verbindung mit den simple tools Gedanken machen.


        Once every class creation.
        so everytime when a new instance of python is started following steps will be triggert.

        # Two main purposes
            - set up drag&drop package (unzipping flasher, eventually installng romloader)
            - prepare all variables, flasher path etc for following tests

        This uses arg-parse of the flasherEnv. Use help of it for future advice
        :return:
        """

        l.info("Enter Setup Class!")

        compare_path = '/home/SambaShare/gitScript/scripts/python/eclipseWB/org.muhkuh.tools-flasher/regression'

        maintained_archive = package_root
        if os.path.exists(compare_path):
            if realpath(compare_path) == realpath(dirname(__file__)):
                # for local debugging, a quick check.
                maintained_archive = '/home/aballmert/Downloads/ptbt_0.1.291-1.6.0_rc2_betabuild'

        log_path = os.path.join(maintained_archive, 'logfiles')
        # todo: this is the most ugliest way of fixing redundant logfile folders...
        # clear archived
        archived_dir = 'zip path'

        path_file_version_json = os.path.join(maintained_archive, 'version.json')

        # logfile_manager is created inside flasher.
        # it's now passed into all other files.
        cls.flasher_env = EnvFlasher(log_path, path_file_version_json, maintained_archive)
        cls.lfm = cls.flasher_env.lfm

        loc_list_black, loc_list_white = cls.execute_argparse()

        list_connected_netx = \
            cls.flasher_env.identify_connected_netx(
                list_white=loc_list_white,
                list_black=loc_list_black)

        if len(list_connected_netx) == 0:
            raise Exception("no netX connected!")
        elif len(list_connected_netx) > 1:
            raise Exception("more then one netX connected!")
        connected_netx = list_connected_netx[0]

        pass
        # assignment dict
        # List for setting default helpers
        # they can be overwritten by the dicts in the memory description.
        # todo: separate memory desc, and port desc. --> Jasonixer has done it, so use it!!!
        assignment_list = [
            ['romloader_usb', 'USB'],
            ['romloader_uart', 'UART'],
            ['romloader_jtag', 'JTAG'],
            ['romloader_eth', 'ETHERNET']
        ]

        loc_plugin_name = connected_netx[Jasonixer.json_chip_if_port]
        plug_num = connected_netx['tmp_iterator_detect']
        loc_netx_chip_type = int(connected_netx[Jasonixer.json_chip_type_number])
        loc_netx_chip_type_id = connected_netx[Jasonixer.json_chip_type_identifyer]
        loc_protocol = connected_netx[Jasonixer.json_chip_flasher_name]

        # interate over default assignment list
        for ele in assignment_list:
            if ele[0] == loc_protocol:
                loc_protocol_alias = ele[1]
                l.info("Detect protocol %s %s" % (ele[0], ele[1]))
                break
        else:
            msg = "could not determine port: %s" % loc_plugin_name
            l.error(msg)
            raise (BaseException(msg))

        # todo: all infos are already in the class list_connected_netx available.

        # todo: select
        # todo: pull this into jasonixer
        # todo: make use of fash_env
        # select for netX500
        select_list = []
        en_id = 0
        en_ass = 1  # assignment dict  input: port, output: protocol, available if diverges from upper list.
        en_flash = 2
        # value: Detected protocol, key: assumed interface. => assumed interface may be corrected.
        netx500 = [1, {"USB": "USB"},
                   [
                       {"b": 0, "u": 0, "cs": 0, "name": "S29GL128P90", "size": 16 * 1024 * 1024},
                       {"b": 1, "u": 0, "cs": 0, "name": "W25Q32", "size": 4 * 1024 * 1024},
                   ]
                   ]
        select_list.append(netx500)

        netX50 = [3, {"USB": "UART"},
                  [
                      {"b": 0, "u": 0, "cs": 0, "name": "S29GL128P90", "size": 16 * 1024 * 1024},
                      {"b": 1, "u": 0, "cs": 0, "name": "W25Q32", "size": 4 * 1024 * 1024},
                  ]
                  ]
        select_list.append(netX50)

        netX10 = [5, {},
                  [
                      {"b": 0, "u": 0, "cs": 0, "name": "S29GL128P90", "size": 16 * 1024 * 1024},
                      {"b": 1, "u": 0, "cs": 0, "name": "W25Q32", "size": 4 * 1024 * 1024},

                  ]
                  ]
        select_list.append(netX10)

        netX51_52_A = [6, {"USB": "UART"},
                       [
                           {"b": 1, "u": 0, "cs": 0, "name": "W25Q32", "size": 4 * 1024 * 1024},
                       ]
                       ]
        netX51_52_B = copy.deepcopy(netX51_52_A)
        netX51_52_B[en_id] = 7
        select_list.append(netX51_52_A)
        select_list.append(netX51_52_B)

        netx4000 = [11, {"USB": "UART"},
                    [
                        {"b": 1, "u": 0, "cs": 0, "name": "MX25L12835FM2I", "size": 16 * 1024 * 1024},
                        {"b": 3, "u": 0, "cs": 0, "name": "SD-Card_2GB", "size": 1.5 * 1024 * 1024 * 1024},
                        # {"b": 3, "u": 0, "cs": 0, "name": "SD-Card_16GB", "size": 1.5 * 1024 * 1024 * 1024},
                        # {"b": 3, "u": 0, "cs": 0, "name": "eMMC_512MB", "size": 512 * 1024 * 1024},
                    ]
                    ]

        select_list.append(netx4000)

        netX90rev0 = [13, {"USB": "UART"},
                      [
                          {"b": 1, "u": 0, "cs": 0, "name": "W25Q32", "size": 4 * 1024 * 1024},  # netIOL
                          {"b": 2, "u": 0, "cs": 0, "name": "INT flash 0", "size": 512 * 1024},
                          {"b": 2, "u": 1, "cs": 0, "name": "INT flash 1", "size": 512 * 1024},
                          {"b": 2, "u": 2, "cs": 0, "name": "INT flash 2", "size": 512 * 1024},
                          {"b": 2, "u": 3, "cs": 0, "name": "INT flash 0/1", "size": 1024 * 1024},
                      ]
                      ]
        netx90rev1 = copy.deepcopy(netX90rev0)
        netx90rev1[en_id] = 14
        select_list.append(netX90rev0)
        select_list.append(netx90rev1)

        netiol_MPW = [15, {"USB": "UART"},
                      [
                          {"b": 1, "u": 0, "cs": 0, "name": "W25Q32", "size": 4 * 1024 * 1024},  # netIOL
                      ]
                      ]

        netiol_rev0 = copy.deepcopy(netiol_MPW)
        netiol_rev0[en_id] = 16

        select_list.append(netiol_MPW)
        select_list.append(netiol_rev0)

        enx_name = 0  # flasher internal description of netX as assumed
        enx_ct_val = 1  # flasher internal constant value
        enx_ct_id = 2  # flasher internal constant (enum name)
        # https://kb.hilscher.com/x/KYBOBQ

        # this is unused, but was intended to be used. hold it here for later purpose.
        x = [["unknown chip", 0, "ROMLOADER_CHIPTYP_UNKNOWN"],
             ["netX500	", 1, "ROMLOADER_CHIPTYP_NETX500"],
             ["netX100	", 2, "ROMLOADER_CHIPTYP_NETX100"],
             ["netX50	", 3, "ROMLOADER_CHIPTYP_NETX50"],
             ["netX10	", 5, "ROMLOADER_CHIPTYP_NETX10"],
             ["netX51/52 Step A", 6, "ROMLOADER_CHIPTYP_NETX56"],
             ["netX51/52 Step B", 7, "ROMLOADER_CHIPTYP_NETX56B"],
             ["netX4000 RLXD", 8, "ROMLOADER_CHIPTYP_NETX4000_RELAXED"],
             ["netX4000 Full", 11, "ROMLOADER_CHIPTYP_NETX4000_FULL"],
             ["netX4100 Small", 12, "ROMLOADER_CHIPTYP_NETX4100_SMALL"],
             ["netX90MPW", 10, "ROMLOADER_CHIPTYP_NETX90_MPW"],
             ["netX90 Rev0", 13, "ROMLOADER_CHIPTYP_NETX90"],
             ["netX90 Rev1", 14, "ROMLOADER_CHIPTYP_NETX90B"],
             ["netIOL MPW", 15, "ROMLOADER_CHIPTYP_NETIOLA"],
             ["netIOL Rev0", 16, "ROMLOADER_CHIPTYP_NETIOLB"]]



        # set up transfare structures
        # Todo: Later use Janonixer structures for it
        for ele in select_list:
            # check netX ID against registered ID's in list generated above
            if ele[en_id] == loc_netx_chip_type:
                dict_tabl = ele[en_ass]
                # If there is a translation dict inside, use the key from the translation dict.
                # if not, use the default one. assigned in the short table
                for key in dict_tabl:
                    if dict_tabl[key] == loc_protocol_alias:
                        loc_connected_port_type = key
                        break
                else:
                    loc_connected_port_type = loc_protocol_alias
        # todo: transfare into jasonixer
                cls.plugin_name = {
                    "plugin_name": loc_plugin_name,
                    "plug_num": plug_num,
                    "netx_port": loc_connected_port_type,
                    "netx_protocol": loc_protocol_alias,
                    "netx_chip_type": loc_netx_chip_type,
                    "netx_chip_type_id": loc_netx_chip_type_id}
                cls.memories_to_test = ele[en_flash]
                break
        else:
            raise (BaseException("No flash found according to ID"))

        # Set the binary path for lua for executing the flasher. retrieved from flasher_env
        cls.path_flasher_binary = cls.flasher_env.ref_flash.gPath_lua_binary
        cls.path_flasher_files = cls.flasher_env.ref_flash.gpathAbs_flasher
        # todo: manage logfile directory creation ans so on. probably run every test in a subdir
        #cls.path_logfiles = log_path

        # test group
        # * short
        # * standard
        # * extended
        # * detailed
        # * special
        # self.testGroupInternal = ["short", "special"]

    @classmethod
    def execute_argparse(cls):
        # parse arguments
        args = cls.flasher_env.parser.parse_args()
        # todo: more errorhandling in installing. Check also if alreaydy is installed.
        if hasattr(args, 'install'):
            # install and exit
            ret = cls.flasher_env.runInstallation(force32=args.f32)
            if ret == 0:
                if hasattr(args, 'test_romloader'):
                    ret = cls.flasher_env.apply_test_romloader()
            exit(ret)
        else:
            l.info("Has no install!")
        if hasattr(args, 'uuid'):
            if args.uuid:
                Dyntest.uuid_test = args.uuid
            else:
                Dyntest.set_random_uuid()
        else:
            Dyntest.set_random_uuid()
        if hasattr(args, 'mode'):
            cls.RunTestsGroups = args.mode  # ["regr_short"]
        if hasattr(args, 'list_black'):
            loc_list_black = args.list_black
            l.info("[setup] recieved list_black from command line: %s" % loc_list_black)
        else:
            loc_list_black = None
        if hasattr(args, 'list_whit'):
            loc_list_white = args.list_whit
            l.info("[setup] recieved list_black from command line: %s" % loc_list_white)
        else:
            loc_list_white = None
        return loc_list_black, loc_list_white

    def setUp(self):
        # inc major index
        Dyntest.iteration_index += 1  # will also be executed for skipped tests, even if no log exists!

        tmp_logfile_path_last_run = self.lfm.path_abs_logfiles_temporary

        # gen log json of test.
        filename_logintro = 'testconfig_%s.json' % Dyntest.uuid_test
        path_loginfo = os.path.join(tmp_logfile_path_last_run, filename_logintro)
        with open(path_loginfo, 'wb') as outfile:
            compress = {"memories": self.memories_to_test, "plugins": self.plugin_name}
            json.dump(compress, outfile, indent=2)

    @classmethod
    def tearDownClass(cls):
        pass

    def test_wfp_complete(self):
        enable_test = 0
        for TestGroup in self.RunTestsGroups:
            if TestGroup in ["wfp_complete", "all"]:
                # set flasg to enable test
                enable_test = 1

        if not enable_test:
            self.skipTest("test_wfp_complete NOT inlcuded inside test group(s): %s" % self.RunTestsGroups)

        test_started = 0
        test_results = 0
        for memory_to_test in self.memories_to_test:
            # test requires external SQI flash
            if (memory_to_test["b"] in [1] and
                    memory_to_test["u"] in [0] and
                    memory_to_test["cs"] in [0] and
                    memory_to_test["size"] > 1 * 1024 * 1024):
                test_started = 1
            else:
                # skip other memory interfaces
                l.info(" *** Skip for netX %d memory: %s" % (self.plugin_name["netx_chip_type"], memory_to_test))
                continue

            tc = TestWfp(self.lfm)
            tc.init_params(self.plugin_name, memory_to_test,
                           0,
                           self.path_flasher_files,
                           self.path_flasher_binary,
                           {})
            tc.run_test()
            test_result = tc.numErrors_a[-1]
            # collect all test results
            test_results += test_result[1]

    # what ever name follows test_*(): doesn't matter.
    def test_Standard_SQI_flash(self):
        """
        Testdescription
        flasher CLI standard tests
        executed only at external SQI flash at parameter "-b 1 -u 0 -cs 0"

        :return:
        """
        # skip test, if not inside the list to be executed
        enable_test = 0
        for TestGroup in self.RunTestsGroups:
            if TestGroup in ["regr_short", "regr_standard", "all"]:
                # set flasg to enable test
                enable_test = 1

        if not enable_test:
            self.skipTest("test_Standard_SQI_flash NOT inlcuded inside test group(s): %s" % self.RunTestsGroups)

        num_bytes_to_test = 1024 * 1024

        test_started = 0
        test_results = 0
        for memory_to_test in self.memories_to_test:
            # test requires external SQI flash
            if (memory_to_test["b"] in [1] and
                memory_to_test["u"] in [0] and
                memory_to_test["cs"] in [0] and
                memory_to_test["size"] > 1 * 1024 * 1024):
                test_started = 1
            else:
                # skip other memory interfaces
                l.info(" *** Skip for netX %d memory: %s" % (self.plugin_name["netx_chip_type"], memory_to_test))
                continue

            tc = FltStandardSqiFlash(self.lfm)
            tc.init_params(self.plugin_name, memory_to_test,
                           num_bytes_to_test,
                           self.path_flasher_files,
                           self.path_flasher_binary,
                           {})
            tc.run_test()
            test_result = tc.numErrors_a[-1]
            # collect all test results
            test_results += test_result[1]

        if test_started == 1:
            self.assertEqual(0, test_results)
        else:
            self.fail("No SQI flash available for netX %d" % self.plugin_name["netx_chip_type"])

    def test_Standard_Other_Flashes(self):
        """
        Testdescription
        flasher CLI standard tests
        executed always except at external SQI flash at parameter "-b 1 -u 0 -cs 0"

        :return:
        """

        # skip test, if not inside the list to be executed
        enableTest = 0
        for TestGroup in self.RunTestsGroups:
            if TestGroup in ["regr_standard", "all"]:
                # set flasg to enable test
                enableTest = 1

        if not enableTest:
            self.skipTest("test_Standard_Other_Flashes NOT inlcuded inside test group(s): %s" % self.RunTestsGroups)

        num_bytes_to_test = 1024 * 1024

        test_started = 0
        test_results = 0
        for memory_to_test in self.memories_to_test:
            # skip SQI flash, because this is tested inside dedicated test
            if (memory_to_test["b"] in [1] and
                memory_to_test["u"] in [0] and
                memory_to_test["cs"] in [0]):
                continue

            test_started = 1
            # todo: Memory to thest cpould occure in lofile name, if desired.
            l.info(" *** Started for netX %d memory: %s" % (self.plugin_name["netx_chip_type"], memory_to_test))

            tc = FltStandardOtherFlash(self.lfm)
            tc.set_last_comment(memory_to_test['name'])
            tc.init_params(self.plugin_name, memory_to_test,
                           num_bytes_to_test,
                           self.path_flasher_files,
                           self.path_flasher_binary,
                           {})
            tc.run_test()
            test_result = tc.numErrors_a[-1]
            # collect all test results
            test_results += test_result[1]



        if test_started == 1:
            self.assertEqual(0, test_results)
        else:
            self.skipTest("No other memories connected / to be tested for netX %s" % self.plugin_name["netx_chip_type"])

    def test_hash_SQI_flash(self):
        """
        Testdescription
        flasher CLI HASH tests

        :return:
        """

        # skip test, if not inside the list to be executed
        enable_test = 0
        for TestGroup in self.RunTestsGroups:
            if TestGroup in ["regr_standard", "all"]:
                # set flasg to enable test
                enable_test = 1

        if not enable_test:
            self.skipTest("test_hash_SQI_flash NOT inlcuded inside test group(s): %s" % self.RunTestsGroups)

        # skip because the flasher for netX 90, netIOL => does not implement the hash function
        if self.plugin_name["netx_chip_type"] in [10, 13, 14, 15, 16]:
            self.skipTest("not supported for netX 90 and netIOL")

        num_bytes_to_test = 1024 * 1024

        test_started = 0
        test_results = 0
        for memory_to_test in self.memories_to_test:
            # test requires external SQI flash
            if (memory_to_test["b"] in [1] and
                memory_to_test["u"] in [0] and
                memory_to_test["cs"] in [0] and
                memory_to_test["size"] > 1 * 1024 * 1024):
                test_started = 1
            else:
                # skip other memory interfaces
                l.info(" *** Skip for netX %d memory: %s" % (self.plugin_name["netx_chip_type"], memory_to_test))
                continue

            tc = FltHash(self.lfm)
            tc.init_params(self.plugin_name, memory_to_test,
                           num_bytes_to_test,
                           self.path_flasher_files,
                           self.path_flasher_binary,
                           {})
            tc.run_test()
            test_result = tc.numErrors_a[-1]
            # collect all test results
            test_results += test_result[1]

        if test_started == 1:
            self.assertEqual(0, test_results)
        else:
            self.fail("No SQI flash available for netX %d" % self.plugin_name["netx_chip_type"])

    def test_testcli_SQI_flash(self):
        """
        Testdescription
        run test "testcli" only on SQI flash

        :return:
        """

        # skip test, if not inside the list to be executed
        enable_test = 0
        for TestGroup in self.RunTestsGroups:
            if TestGroup in ["regr_long", "all"]:
                # set flasg to enable test
                enable_test = 1

        if not enable_test:
            self.skipTest("test_testcli_SQI_flash NOT inlcuded inside test group(s): %s" % self.RunTestsGroups)

        test_started = 0
        test_results = 0
        for memory_to_test in self.memories_to_test:
            # test requires external SQI flash
            if (memory_to_test["b"] in [1] and
                memory_to_test["u"] in [0] and
                memory_to_test["cs"] in [0]):
                test_started = 1
            else:
                # skip other memory interfaces
                l.info(" *** Skip for netX %d memory: %s" % (self.plugin_name["netx_chip_type"], memory_to_test))
                continue


            tc = FltTestcliSqiFlash(self.lfm)
            # todo move this memory to test to upper function. the loop at this place is not pleasant for all autopilot
            tc.set_last_comment(memory_to_test['name'])
            tc.init_params(self.plugin_name, memory_to_test,
                           "",
                           self.path_flasher_files,
                           self.path_flasher_binary,
                           {})
            tc.run_test()
            test_result = tc.numErrors_a[-1]
            # collect all test results
            test_results += test_result[1]

        if test_started == 1:
            self.assertEqual(0, test_results)
        else:
            self.fail("No SQI flash available for netX %d" % self.plugin_name["netx_chip_type"])

    def test_NXTFLASHER_51(self):
        """
        Testdescription

        :return:
        """

        # skip test, if not inside the list to be executed
        enableTest = 0
        for TestGroup in self.RunTestsGroups:
            if TestGroup in ["NXTFLASHER_51", "all"]:
                # set flasg to enable test
                enableTest = 1

        if not enableTest:
            self.skipTest("test_NXTFLASHER_51 NOT inlcuded inside test group(s): %s" % self.RunTestsGroups)

        # execute only for netX56B
        if self.plugin_name["netx_chip_type"] in [7]:
            pass
        else:
            self.skipTest("Test NXTFLASHER_51 only for netX56B")

        # loop over all available flashes
        test_results = 0
        # store information, if a test was executed
        test_started = 0
        for memory_to_test in self.memories_to_test:

            # test requires external SQI flash
            if (memory_to_test["b"] in [1] and
                    memory_to_test["u"] in [0] and
                    memory_to_test["cs"] in [0] and
                    memory_to_test["size"] > 1 * 1024 * 1024):
                test_started = 1
            else:
                # skip the sub test
                continue

            tc = NxtFlasher_51(self.lfm)
            tc.set_last_comment(memory_to_test['name'])
            tc.init_params(self.plugin_name, memory_to_test,
                           "",
                           self.path_flasher_files,
                           self.path_flasher_binary,
                           {})
            tc.run_test()
            test_result = tc.numErrors_a[-1]
            # collect all test results
            test_results += test_result[1]

        if test_started == 1:
            self.assertEqual(0, test_results)
        else:
            self.skipTest("Test only for netX56B with external SQI flash")

    def test_NXTFLASHER_55(self):
        """
        Testdescription

        if special SW is running, than the flasher can not connect to the netX via JTAG port
        tested with netX 90 rev 0

        NXHX90-JTAG REV3 No 20160

        :return:
        """

        # skip test, if not inside the list to be executed
        enableTest = 0
        for TestGroup in self.RunTestsGroups:
            if TestGroup in ["NXTFLASHER_55", "all"]:
                # set flasg to enable test
                enableTest = 1

        if not enableTest:
            self.skipTest("test_NXTFLASHER_55 NOT inlcuded inside test group(s): %s" % self.RunTestsGroups)

        # TODO: port test case to netX 90 rev 1

        # execute only for netX 90 rev 0
        if self.plugin_name["netx_chip_type"] in [13]:
            pass
        else:
            self.skipTest("Test %s only for netX 90 rev0" % NxtFlasher_55().__class__.__name__)

        tc = NxtFlasher_55(self.lfm)
        memory_to_test = {"b": 2, "u": 3, "cs": 0, "name": "INT flash 0/1", "size": 1024 * 1024}  # use dummy values
        tc.init_params(self.plugin_name, memory_to_test,
                       "",
                       self.path_flasher_files,
                       self.path_flasher_binary,
                       {})
        tc.run_test()
        test_result = tc.numErrors_a[-1]
        self.assertEqual(0, test_result[1])


if __name__ == '__main__':
    # umgehen des strikten Verhaltens des Unit tests!
    local_path = os.path.dirname(__file__)
    # runner = HtmlTestRunner.HTMLTestRunner(output='/tmp') # for htmlreport
    runner = unittest.TextTestRunner()  # insert result class here...
    runner.verbosity = 2
    loader = unittest.TestLoader()
    test = loader.discover(local_path, pattern="test_regression.py", top_level_dir=local_path)
    test_suit = unittest.TestSuite(test)
    result_class = runner.run(test_suit)
    print("")  # BKP
    result_class.printErrors()
    l.info("End of test, result: %s"%result_class)
    # eval errors:
    hard_errors = len(result_class.errors)
    test_errors = len(result_class.failures)

    if(result_class.skipped):
        l.info("display skipped:")
        for entry in result_class.skipped:
            test_name = entry[0]._testMethodName
            skipping_reason = entry[1]
            l.info("\t[%s]: %s"% (test_name, skipping_reason))
    if(hard_errors):
        l.error("several errors in the sourrounding of the test have occured")
        for entry in result_class.errors:
            test_name = "Framework Error"
            skipping_reason = entry[1]
            l.info("\t[%s]: %s"% (test_name, skipping_reason))
        exit(2)
    if(test_errors):
        l.error("Some test failed. (%d)"%test_errors)
        l.error("several errors in the sourrounding of the test have occured")
        for entry in result_class.failures:
            test_name = entry[0]._testMethodName
            skipping_reason = entry[1]
            l.info("\t[%s]: %s"% (test_name, skipping_reason))
        exit(1)
