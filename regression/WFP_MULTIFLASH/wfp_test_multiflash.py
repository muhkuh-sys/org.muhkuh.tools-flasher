
from WFP.wfp_test_flash import *

root__ = os.path.dirname(os.path.realpath(__file__))
base_root = os.path.dirname(root__)  # location where all projects reside

# print base_root
sys.path.append(base_root)

NUMBER_OF_TESTFILES = 1


class TestWfpMultiFlash(Flashertest):
    """
    define the standard tests
    """

    test_command_list = None

    binary_file_read_from_netx = None
    binary_file_write_to_netx = None
    user_inupt_assign = {}

    def __init__(self, lfm):
        Flashertest.__init__(self, lfm)
        # self.test_binary_size = 5 * 1024
        self.test_files = {}
        self.memory_to_test = None
        self.plugin = plugin_name = None
        self.user_inupt_assign = {}

    def get_target_data(self):
        tree = parse(self.wfp_xml_path)
        root = tree.getroot()
        self.test_data = {}
        for target in root.getchildren():
            if not target.tag == "Target":
                continue
            if not target.attrib['netx'] == CHIP_TYPE[self.chip_id]:
                continue
            self.test_data['target'] = {}
            for i, command in enumerate(target.getchildren()):
                self.test_data['target'][i] = command.attrib
                self.test_data['target'][i]['bus'] = FLASHER_BUS_NAME[command.attrib['bus']]
                self.test_data['target'][i]['files'] = {}
                for j, data in enumerate(command.getchildren()):
                    self.test_data['target'][i]['files'][j] = {}
                    self.test_data['target'][i]['files'][j] = data.attrib

            print("ok")


    def init_params(self, plugin_name, memories_to_test, test_binary_size, path_lua_files, flasher_binary,
                    dict_add_params):



        self.command_structure = []
        self.path_lua_files = path_lua_files
        self.flasher_binary = flasher_binary
        self.dict_add_params = dict_add_params

        self.memories_to_test = memories_to_test
        #  get the plugin name of the board
        self.plugin_name = "-p %s" % plugin_name["plugin_name"]

        # get plugin number
        self.plug_num = plugin_name['plug_num']
        self.bool_params_init = True
        self.chip_id = plugin_name['netx_chip_type']

        # self.get_target_data()

    def pre_test_step(self):
        enable_flasher = {"flasher": True}
        wfp_flash = {"wfp": {"user_input": self.plug_num}}
        wfp_pack = {"wfp": {}}

        # setup wfp.xml for test
        root = Element("FlasherPackage", version="1.0.0")
        # add target
        xml_target = SubElement(root, "Target", netx=CHIP_TYPE[self.chip_id])
        verifies = []

        self.wfp_dir_path = os.path.join(self.lfm.get_dir_tmp_logfiles(), "wfp_archive")
        self.wfp_zip_path = os.path.join(self.lfm.get_dir_tmp_logfiles(), "wfp_archive_.zip")

        if os.path.exists(self.wfp_dir_path):
            shutil.rmtree(self.wfp_dir_path)
        os.makedirs(self.wfp_dir_path)
        if os.path.exists(self.wfp_zip_path):
            os.remove(self.wfp_zip_path)

        self.wfp_xml_path = os.path.join(self.wfp_dir_path, "wfp.xml")


        for memory_to_test in self.memories_to_test:
            xml_flash_cmd = SubElement(xml_target,
                                       "Flash",
                                       bus=FLASHER_BUS_ID.get(int(memory_to_test['b'])),
                                       unit="%s" % memory_to_test['u'],
                                       chip_select="%s" % memory_to_test['cs'])

            self.memory_to_test = memory_to_test
            self.bus_port_parameters_flasher = "-b %s -u %s -cs %s" % (memory_to_test['b'],
                                                                       memory_to_test["u"],
                                                                       memory_to_test['cs'])
            self.test_binary_size = self.memory_to_test['size']

            for i in range(NUMBER_OF_TESTFILES):
                self.test_files[i] = {"file": "random_file_b%s_u%s_cs%s_%i.bin" % (memory_to_test['b'],
                                                                                   memory_to_test["u"],
                                                                                   memory_to_test['cs'],
                                                                                   i)}
            file_sizes, empty_files = get_random_file_sizes(NUMBER_OF_TESTFILES,
                                                            self.memory_to_test['size'] / 1024,
                                                            puffer=4, max_size=20)


            # create random binary files for wfp flash test
            for i, test_file in enumerate(self.test_files.values()):
                test_file.update(file_sizes[i])
                # generate random files
                generate_random_file_by_size_and_name(os.path.join(self.wfp_dir_path, test_file['file']),
                                                      test_file['size'] * 1024)

                SubElement(xml_flash_cmd, "Data",
                           file=test_file['file'],
                           offset="0x%08X" % (test_file['offset'] * 1024))

            self.command_structure.append([enable_flasher, "cli_flash.lua", "erase", self.bus_port_parameters_flasher,
                                           "-l 0x%x" % self.test_binary_size, self.plugin_name])


            for data in self.test_files.values():
                file_path = os.path.realpath(os.path.join(self.wfp_dir_path, data['file']))
                verifies.append([enable_flasher,
                                               "cli_flash.lua",
                                               "verify",
                                               self.bus_port_parameters_flasher,
                                               self.plugin_name,
                                               "-s", "0x%08X" % (data['offset']*1024),
                                               file_path])


        self.command_structure.append([wfp_flash, "wfp.lua", "pack", self.wfp_xml_path, self.wfp_zip_path])
        self.command_structure.append([wfp_flash, "wfp.lua", "flash", self.wfp_zip_path])
        self.command_structure.extend(verifies)
        xml_string = tostring(root)
        parsed_xml = parseString(xml_string)
        data = parsed_xml.toprettyxml()
        with open(self.wfp_xml_path, "w") as my_xml:
            my_xml.write(data)

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
                elif prog == "wfp":
                    user_input = dict_prog_select['wfp'].get('user_input', None)
                    # concat all to one string
                    tmp_final_test_command = self.flasher_binary
                    # make full file path
                    tmp_full_file_path = os.path.join(self.path_lua_files, ele[parameter_start])
                    self.command_structure[idx][parameter_start] = tmp_full_file_path
                    # assign a user input to a command string
                    if user_input:
                        self.user_inupt_assign[idx] = user_input
                else:
                    l.error("key %s is not supported" % prog)

            for int_ele in ele[parameter_start:]:
                tmp_final_test_command += " %s" % int_ele
            # append
            self.command_strings.append(tmp_final_test_command)
            # todo: later: this should be also a json tolerant structure, combining input and output.
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
            self.uuid_test,
            #  added to hand over user input parameter, that need to be set during execution of a command
            self.user_inupt_assign
        )
        self.numErrors += eval_batch_result(
            carrier_result,
            self.lfm.get_dir_tmp_logfiles(),
            self.logfile_prefix,
            "%s %s" % (self.uuid_test, self.__class__.__name__))
        self.numErrors_a.append([self.uuid_test, self.numErrors, self.__class__.__name__, len(self.command_strings)])

    def init_command_array(self):
        pass
