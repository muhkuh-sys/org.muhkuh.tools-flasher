# how to test?

This is a old refurbished version of the flasher test 1.6.0.
There is no butler and no simple tool box. You will use python2
to run this test. File to start test is `test_regression.py`. Follow instructions provided by argparse.

The test structure is a straight forward. Flasher commands will be executed in a row.
If all succeed, test has passed. The result and the runtime of the test are listed.

The user can decide via command line arguments, which test or test group to start.   

# Logfiles 
Logfiles ot the test will be found in logs-folder.

    /logfiles/logs_final_zip:
    - 93707950-04_00-20200804_074224-Linux-x86_64logfiles_FltStandardSqiFlash_.zip
        contains result of all executed flasher commands
    - 93707950-04_00-20200804_074224-Linux-x86_64logfiles_FltStandardSqiFlash_.json:
       {
         "num_sub_tests": 10, 
          "Name_Test": "FltStandardSqiFlash", 
          "Tesdescription": "93707950-04_00-20200804_074224-Linux-x86_64logfiles_FltStandardSqiFlash_", 
          "result": 0  <- number of failed tests. 
        }
        
*Evere test provides it's own json file.*
    
    
This test is improved with all additional files needed. So it can run out od the box. 
