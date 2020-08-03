import json, os


from common.simpelTools.src.logging_default import *



class Jasotester:
    """
    json_test

    - test ID
    - VM ( Jenkins dates )
    -test 01
      [
        { command01, retval=0, time=123,  message }
      - command 02
      - command 03
    -test 02
    -test 03
    """
    json_start_node = "test_result"



class Jasonixer:

    # key from config json
    json_start_node = "test_config"
    json_board_name = "board_name"
    json_board_id = "board_id_maj_first"
    json_chip = "chip"
    json_chip_type_number = "chip_type_value"
    json_chip_flasher_name = "flasher_name"
    json_chip_type_name = "chip_type_name"
    json_chip_type_identifyer = "chip_type_identifyer"
    json_chip_name = "chip_name"
    json_chip_interfaces = "interfaces"
    json_chip_if_port = "netx_port"
    json_chip_if_protocol = "netx_protocol"
    json_chip_tmp_it = "tmp_iterator_detect"  # iterator when detecting netX. useful for los


    # memory
    json_memory = "memory_available"
    json_memory_name_bus = "memory_name_bus"
    json_memory_name_unit = "memory_name_unit"
    json_memory_order_number = "order_number"
    json_memory_manufacture = "manufacture"
    json_memory_size = "memory_size_byte"
    json_memory_code = "select_code_memory"






    def __init__(self, path_to_board_config):

        assert(os.path.exists(path_to_board_config))
        self.path_file_board_config = path_to_board_config
        self.dict_config_file = self.init_json_files()
        self.boards = self.dict_config_file[self.json_start_node]
        self.dict_selected_board = None

        self.dump_local_config(self.dict_config_file, 'init')

        pass

    def set_board_by_chip_id(self,desired_chip_id):
        for board in self.boards:
            id_now = board[self.json_chip][self.json_chip_type_number]
            if id_now == desired_chip_id:
                self.dict_selected_board = board
                l.info("with chip id [%d] select board: %s"%(desired_chip_id,board[self.json_board_name]))
                return
        else:
            l.error("no chip matches ID!")
            assert(False)
        pass

    def init_json_files(self):
        """

        :rtype: dict
        """
        try:
            with open(self.path_file_board_config, "rb") as read_file:
                final_json = json.load(read_file)
        except BaseException as e:
            l.error(e.message)
            raise e
        return final_json

    def get_dict_config_file(self):
        return self.dict_config_file

    def get_board(self):
        """
        Returns the board if already selected, ,else default value (none)
        :return:
        """
        return self.dict_selected_board

    @classmethod
    def dev_convert_memory_to_commandline_parameter(cls, dict_memory):
        """
        expect:
        {
            "memory_type":"Serial Flash",
            ...
            "select_code": {   # mandatory element
                "b": 1, # number of elements does not matter, mandatory is Key:Value-format
                "u": 0
        }
        build: -b 1 -u 0
        :param dict_memory: A dictionary representing json abouve
        :return: string
        """
        tmp_parameters = ''

        for ele in dict_memory[cls.json_memory_code]:
            tmp_parameters += ("-%s %s " % (ele, dict_memory[cls.json_memory_code][ele]))
        return tmp_parameters.strip()

    def get_command_line_parameters_for_memories(self):
        command_line_parameters = []
        for memory in self.dict_selected_board[self.json_memory]:
            tmp_command_line_parameters = self.dev_convert_memory_to_commandline_parameter(memory)
            command_line_parameters.append(tmp_command_line_parameters)
        return command_line_parameters



    @classmethod
    def generate_example_total_config(cls, workfile):

        example_config = cls.generate_desc_base_config()

        # init the board config which contains the description over all boards
        board_id_revision_number = ['board_manufacture_number', 'revision', 'serial_number']
        board_to_be_created = cls.generae_desc_empty_board('NXHX-Board123', board_id_revision_number)

        for num_stroage in range(0,3):

            tmp_memory_ele = cls.generate_desc_memory(num_stroage)
            # append memory to board
            board_to_be_created[cls.json_memory].append(tmp_memory_ele)

        # append board to dictionary
        example_config[cls.json_start_node].append(board_to_be_created)

        cls.dump_local_config(example_config, 'gen_example')
        if workfile:
            with open(workfile, 'wb') as file_handle:
                json.dump(example_config, file_handle, indent=2, sort_keys=True)
                l.info("dumped json file with example config to %s"%workfile)
        return example_config

    def dump_config_to_file(self, path_to_json_file):
        """
        dumps the active configuration to a json file
        :return: generates file
        """
        path_to_file = os.path.abspath(path_to_json_file)
        os.path.exists(path_to_file)

        with open(path_to_json_file, 'wb') as file_handle:
            json.dump(self.dict_config_file, file_handle, indent=2, sort_keys=True)
            l.info("stored config to >%s<" % path_to_json_file)

    def append_example_board_to_config(self, num_memories):

        # generate additional example config
        # init the board config which contains the description over all boards
        board_id_revision_number = ['123234', '2', '123dsdf2431']
        board_to_be_created = self.generae_desc_empty_board('NXHX-Added', board_id_revision_number)

        for num_stroage in range(0, num_memories):

            tmp_memory_ele = self.generate_desc_memory(num_stroage)
            # append memory to board
            board_to_be_created[self.json_memory].append(tmp_memory_ele)



        self.dict_config_file[self.json_start_node].append(board_to_be_created)



    @classmethod
    def generate_desc_base_config(cls):
        example_config = {}
        example_config[cls.json_start_node] = []
        return example_config

    @classmethod
    def generae_desc_empty_board(cls, board_name, board_id_array):
        assert( type(board_id_array) is list)  # e.g.: 'NXHX-Was-Auch-immer-Du-Hast'
        assert( type(board_name) is str)       # e.g.: ['board_manufacture_number', 'revision', 'serial_number']
        board_to_be_created = {}

        chip_on_board = cls.generate_desc_empty_chip()

        board_to_be_created[cls.json_board_name] = board_name
        board_to_be_created[cls.json_chip] = chip_on_board
        board_to_be_created[cls.json_board_id] = board_id_array
        board_to_be_created[cls.json_memory] = []


        return board_to_be_created

    @classmethod
    def generate_desc_empty_chip(cls, num=None, name=None, interfaces=None, tmp_port=None):
        chip_on_board = {}
        if num:
            chip_on_board[cls.json_chip_type_number] = num
        else:
            chip_on_board[cls.json_chip_type_number] = 0

        if name:
            chip_on_board[cls.json_chip_flasher_name] = name
        else:
            chip_on_board[cls.json_chip_flasher_name] = "column_2_not_set"  #""c_2: netX90 Rev0"

        if tmp_port:
            chip_on_board[cls.json_chip_if_port] = tmp_port
        else:
            chip_on_board[cls.json_chip_if_port] = "the minus p parameter"



        #chip_on_board["chip_type_value_"] = "number from flasher (c5)"
        chip_on_board[cls.json_chip_name] = "column_1_not_set"  #""c_1: netX90"
        #chip_on_board[cls.json_chip_flasher_name] = "c_2: netX90 Rev0"
        chip_on_board[cls.json_chip_type_name] = "column_3_not_set"  #""c_3_netX 90 Rev0"
        chip_on_board[cls.json_chip_type_identifyer] = "column_4_not_set"  #"c_4_netx90_rev0"

        interfaces = cls.generate_desc_chip_if(interfaces)

        chip_on_board[cls.json_chip_interfaces] = interfaces
        return chip_on_board

    @classmethod
    def print_chip(cls, dict_chip):
        l.info("[%s] %s (%s)"%(dict_chip[cls.json_chip_type_number],
                              dict_chip[cls.json_chip_flasher_name],
                              dict_chip[cls.json_chip_if_port]))


    @classmethod
    def generate_desc_chip_if(cls, interfaces=None):

        final = []
        if interfaces:
            # check
            for ele in interfaces:
                if type(ele) is not (tuple and list):
                    raise(BaseException("Provide array or list with tuples size of 2 describing the interfaces and protcol"))
                if len(ele) != 2:
                    raise(BaseException("Elements defining memory must be with length of 2"))

            interf = interfaces
        else:
            # use demo IF
            interf = [("xJTAG", "yJTAG"), ("xUSB", "yUSB"), ("xUSB", "yUART")]
        for interface in interf:
            plug = {cls.json_chip_if_port: interface[0], cls.json_chip_if_protocol: interface[1]}
            final.append(plug)

        return final

    @classmethod
    def generate_desc_memory(cls, seed):
        """
        Generates a dafault description of a memory,
        which can be later appended to a memory of a board
        :param seed: A default parameter to make each example memory indidual
        :return: a dictionary representing a memory
        """
        tmp_memory_ele = {
            cls.json_memory_name_bus: "read_dyn_from info ( bus_name )",
            cls.json_memory_name_unit: "read_dyn_from info ( unit_name )",
            cls.json_memory_order_number: "S12345_from_amaonte c s---2",
            cls.json_memory_manufacture: "future Technologies%d" % seed,
            cls.json_memory_size: 1024 * ((1 + seed) * 2),
            cls.json_memory_code: {
                "b": 42,
                "u": 69
            }
        }
        return tmp_memory_ele



def demo():
    workfile = "./temporary_confoig_file.json"
    out_workfile = "./temporary_confoig_file_out.json"
    l.info("write example file to %s"%workfile)
    Jasonixer.generate_example_total_config(workfile)
    l.info("Read back generated file and init jasonixer")
    jasonixer = Jasonixer(workfile)
    l.info("find board according to chiptype later by board_ID")
    jasonixer.set_board_by_chip_id(-42)
    l.info("get command line parameters for memory")
    cmd_line_param = jasonixer.get_command_line_parameters_for_memories()
    l.info(cmd_line_param)
    l.info("Add to the configuration a other demoboard, later default values can be changed in the resulting json")
    jasonixer.append_example_board_to_config(2)
    jasonixer.append_example_board_to_config(4)
    #jasonixer.dump_local_config(jasonixer.dict_config_file, 'control')
    l.info("Dumping new json to file %s"%out_workfile)
    jasonixer.dump_config_to_file(out_workfile)

def test_memory_input():
    """
    expected:
    [{'netx_protocol': '1', 'netx_port': 'A'}, {'netx_protocol': '2', 'netx_port': 'B'}, {'netx_protocol': '3', 'netx_port': 'C'}]
    [{'netx_protocol': 'yJTAG', 'netx_port': 'xJTAG'}, {'netx_protocol': 'yUSB', 'netx_port': 'xUSB'}, {'netx_protocol': 'yUART', 'netx_port': 'xUSB'}]
    """
    input = [("A", "1"), ("B", "2"), ("C", "3")]
    output = Jasonixer.generate_desc_chip_if(input)
    print output
    print(Jasonixer.generate_desc_chip_if())


def test_chip_gen():
    tmp_netX = Jasonixer.generate_desc_empty_chip(num=35, name='Der mega netX', interfaces=[["1",2],['a','34']])
    Jasonixer.print_chip(tmp_netX)
    print(tmp_netX)



if __name__ == "__main__":
    test_chip_gen()
    exit()
    test_memory_input()
    demo()