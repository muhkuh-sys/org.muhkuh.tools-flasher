import os, shutil, filecmp, tarfile
import zipfile

from simpelTools.src.logging_default import *


def generate_random_file_by_size_and_name(path_generated_file, test_binary_size):
    """
    simply generates a binary file from given length and given size.
    Removes a old file with the same name!
    :param path_generated_file:
    :param test_binary_size:
    :return:
    """
    try:
        os.remove(path_generated_file)
    except BaseException as e:
        pass
        # l.info(e)

    if test_binary_size > 1024*1024*200:
        raise MemoryError('Cowardly refusing to generate a file with more than 200MB of random test data.'
                          'Might not be necessary and a programmers error.')

    with open(path_generated_file, 'wb') as fout:
        try:
            fout.write(os.urandom(test_binary_size))
            l.info("Generated binary file size 0x%x/0d%d to: %s" % (test_binary_size,test_binary_size, path_generated_file))
        except MemoryError as e:
            l.error("Error raised, probably because of a too large write attempt of %d bytes at once." % test_binary_size)
            raise e


def create_a_folder_if_not_existing(folder, additional_error_message=""):
    """
    Create a folder on given location, if it does not exist.
    The path of the rootfolder has to exist!
    todo: redundant, unfinished error handling
    :param folder: full path of folder which will be created
    :param message: optional parameter for additional info in case of error
    :return:
    """
    try:
        os.mkdir(folder)
    except OSError as e:
        l.debug('Skip logfile folder creation, folder exists', folder)


#        if e.args == (17, 'File exists'):
#            l.debug('Skip logfile folder creation, folder exists', folder)
#        else:
#            l.error("Can't create folder >%s<. Reason %s" % (folder, e.strerror))
#            raise e



# creating folder (non recursive),
# but skipping if existing
def mkdirSkipExistence(strFolder, folder_usage=''):
    """
    todo: redundant, unfinished error handling
    :param strFolder:
    :return:
    """
    if os.path.exists(strFolder):
        pass
    else:
        try:
            os.mkdir(strFolder)
        except OSError as e:
            l.error(
                "Can't create folder[%s] %s or subfolders. Reason %s" % (folder_usage,
                strFolder, e.strerror))
            raise e


def delete_all_files_in_folder(folder_with_files_to_be_deleted):
    """
    This function does not just delete the files, it also mentions which files are deleted.
    Todo: Deleation or reaction to subris is untested!
    :param folder_with_files_to_be_deleted:
    :return:
    """
    try:
        files_to_be_deleted = os.listdir(folder_with_files_to_be_deleted)
    except BaseException as e:
        l.error("folder to reset empty?! %s" % e)
    else:
        if files_to_be_deleted:
            for file_to_be_deleted in files_to_be_deleted:
                l.debug("remove old file: %s" % file_to_be_deleted)
                try:
                    os.remove(os.path.join(folder_with_files_to_be_deleted, file_to_be_deleted))
                except BaseException as e:
                    l.info(e)


def removeFolderTree(rootFolderToBeRemoved):
    """
    Removes all folders with all subdirs in provided list
    rootFolderToBeRemoved folder which will be removed including all subdirectories. !iter object
    """
    # Clear hboot_images, register_dumps, compare
    try:
        shutil.rmtree(rootFolderToBeRemoved)
    except Exception as e:
        l.error("[rmtree exception]:")
        l.error(e)
        raise e




def copyfileByWildcard(nameFileWildcard, dest_dir):
    """
    copies wildcard like the command shell
    :param nameFileWildcard: locationstring, producing list of files/folders
    :param dest_dir: Destination dir or file
    :return:
    """
    import glob
    import shutil
    iErr = 0
    # (https://stackoverflow.com/questions/18371768/python-copy-files-by-wildcards)
    globExpression = r'%s' % nameFileWildcard
    for file in glob.glob(globExpression):
        l.info("copy file: <%s> to <%s>" % (file, dest_dir))
        try:
          shutil.copy(file, dest_dir)
        except Exception as e:
          l.info(e)
          iErr = 56
          break
    return iErr



def extractTarXzLinux(PathToArchive, PathToDestination):
    """
    # waring only useable with linux
    # warning destinationfolder must exist
    :param PathToArchive:
    :param PathToDestination:
    :return:
    """
    command_base_Extract_gx = 'tar fvxJ '
    command_extractOocd = command_base_Extract_gx + PathToArchive + " -C " + PathToDestination
    success = runCommand(command_extractOocd, "extract OOCDfile")
    if success is not 1:
        l.error("extracting failed\nof: %s\nto: %s failed" % (PathToArchive, PathToDestination))
    return success


def helper_compare_binary_files(binary_fiel_from_test, binary_file_read_from_netx):
    int_ierr = 1
    l.info("compare binary files from netX with origiginal one")
    if os.path.isfile(binary_file_read_from_netx):
        # check size of files
        size_orig = os.path.getsize(binary_fiel_from_test)
        size_uploaded = os.path.getsize(binary_fiel_from_test)
        if (size_orig != size_uploaded):
            l.error("File Size does not match")
        else:
            compare_result = filecmp.cmp(binary_fiel_from_test, binary_file_read_from_netx)
            if not compare_result:
                l.error("Binary file content does not match")
            else:
                l.info("Binary files are the same")
                int_ierr = 0
    return int_ierr


def extractTarGz(tarGzFile, destdir):
    """
    # Extract given *.tar.gz to destination directory
    # warning this function is temporarely changing the current working directory!
    # source: http://code.activestate.com/recipes/442503-extracting-targz-files-in-windows/
    # param tarGzFile Tararchive
    # param destDir Dir where to extract the tar-file to
    todo: possible to ommit the cwd?
    :param tarGzFile:
    :param destdir:
    :return:
    """
    dirBackup = os.getcwd()
    try:
        os.chdir(destdir)
        tar = tarfile.open(tarGzFile, 'r:gz')
        for item in tar:
            # print "[unzip]: %s" % (item)
            tar.extract(item)
        l.info('Unzipped all!')
    except IndexError as e:
        l.error("Error: %s\n Have you specified a file to untar?" % (e))
        raise e
    except Exception as e:
        l.info("Error: %s" % (e))
        name = os.getcwd()
        l.info(name[:name.rfind('.')], '<filename>')
        raise e
    os.chdir(dirBackup)


def extractZip(sourceZipFile, TargetFolder):
    zip_ref = zipfile.ZipFile(sourceZipFile, 'r')
    zip_ref.extractall(TargetFolder)
    zip_ref.close()





