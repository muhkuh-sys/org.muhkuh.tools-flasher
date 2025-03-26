import re
import sys
try:
    import git
except:
    raise ImportError("gitpython missing, install using \"pip install gitpython\"")

class gitVersionManager:
    """Class for managing git tags and getting version strings in the flasher and romloader repository."""

    # Regex for the version formats
    versionFormat = r"v\d+\.\d+\.\d+"
    devBranchFormat = r"^dev_v\d+\.\d+\.\d+$"
    devTagFormat = r"v\d+\.\d+\.\d+-dev\d+"
    releaseTagFormat = versionFormat

    def __init__(self, strRepoPath):
        """
        Create a gitVersionManager Object

        :param strRepoPath: path the current repo is in (use "/" for directories, "." for current directory)
        """
        self.repo = git.Repo(strRepoPath)

    def onDevBranch(self):
        """
        Check if current branch is a dev branch (matches the pattern "dev_vX.Y.Z", e.g. dev_v2.1.0)
        
        :return: True if the current branch is a dev branch (e.g. dev_v2.1.0).
        """
        return bool(re.match(self.devBranchFormat, self.getCurrentBranchName()))


    def onMasterBranch(self):
        """
        Check if the current branch is the master branch
        
        :return: True if the current branch is the master branch.
        """
        return self.getCurrentBranchName() == "master"
    
    def findNearestBranch(self):
        """
        Search for the nearest branch in the history (looks forward in time)

        :return: The branch object of the nearest branch.
        """
        currentCommit = self.repo.head.commit

        # Get the branch that is ahead the closest
        for branch in self.repo.remotes["origin"].refs:
            nearest = 0
            nearestBranch = None

            # Avoid "origin/HEAD"
            if branch.name == "origin/HEAD":
                continue

            # Check if the branch is ahead of the current commit
            if self.repo.is_ancestor(currentCommit, branch.commit):
                # Count the number of commits the branch is ahead
                checkCommit = branch.commit
                numAhead = 0
                while checkCommit != currentCommit:
                    numAhead += 1

                    # Get the right parent commit
                    for parentCommit in checkCommit.parents:
                        # If the current commit is an ancestor of the parent, they belong to one branch.
                        # Otherwise, the parent comes from a merge. Do not go that way.
                        if self.repo.is_ancestor(currentCommit, parentCommit):
                            checkCommit = parentCommit
                            break

                print(f"DEBUG: Branch {branch} is {numAhead} Commits ahead of commit {currentCommit.hexsha}")

                # Check if the branch is closer than the last nearest branch
                if nearestBranch == None or nearest > numAhead:
                    nearest = numAhead
                    nearestBranch = branch

        # After checking all branches, return the nearest
        return nearestBranch

    def getCurrentBranch(self):
        """
        Get the branch the repository is currently on.

        Detached Head state requires branch detection:
            1) Search for a branch the current commit is on
            2) Search for the nearest branch that is a descendant of the current commit.
            3) Search for a branch the second parent commit is on

            Finding the branch via the current commit is required when working on submodules.
            If a submodule is provided as a single commit, it is put in a "detached head state"

            Finding the branch via the second parent commit is required in GitHub CI on Pull Requests.
            The Pull Request CI run is executed on a merged repository state.
            The second parent commit is the source commit for merging, the first would be the target.

        :return: The branch object
        :return: True if currently in a merge request context, otherwise false
        """
        currentCommit = self.repo.head.commit

        # Check if there is a branch on the current commit. (Common at submodules)
        for branch in self.repo.remotes["origin"].refs:
            if currentCommit == branch.commit:
                # print("Found branch via current commit: ", branch)
                if branch.name != "origin/HEAD":
                    return branch, False
                
        # Check if there is an ahead branch which is an descendant of the current commit.
        # This is required if a commit which has descendants is used.
        nearestBranch = self.findNearestBranch()
        if nearestBranch is not None:
            return branch, False

        # Check for a Detached Head State with no known branch.
        # This happens on pull request merge commits in GitHub or in submodules.
        # Otherwise check if the current commit is a merge commit (more than 1 parent).
        if self.repo.head.is_detached or self.repo.active_branch is None:
            if len(currentCommit.parents) > 1:
                # The first parent is the target branchs last commit.
                # Since the source branch is relevant, use the second.
                for branch in self.repo.remotes["origin"].refs:
                    if currentCommit.parents[1] == branch.commit:
                        # print("Found branch via parent commit: ", branch)
                        return branch, True

            # If there is no current branch, throw an Exception with some details.
            errorMsg = "ERROR: Branch could not be detected. "
            errorMsg += f"Repository: {self.repo.working_dir}; "
            errorMsg += f"Commit: {currentCommit}"
            raise Exception(errorMsg)

        # If the head is not detached and there is an active branch, return the active branch
        return self.repo.active_branch, False

    def getCurrentBranchName(self):
        """
        Get the name of the current branch
        
        :return: name of the current branch.
        """
        branch, _ = self.getCurrentBranch()
        # Remove "origin/" if present
        if "/" in branch.name:
            return str.split(branch.name, "/")[-1]
        return branch.name

    def getLastTag(self):
        """
        Get the last tag from "git describe"-output
    
        Note that tags will be inherited when merging.
        When merging to master, create a release version tag ("vA.B.C")

        Only works with:
        dev-tags:     "vA.B.C-devD"
        release-tags: "vA.B.C"
        Will abort if other tag is found or branch-tag combination is invalid.
        
        :return: The last git tag object in the current commits history.
        """
        # Get the git describe output, gitpython has no good way of providing the tag
        description = self.repo.git.describe() # e.g. 'v2.1.0-dev13-15-gb39e454' or 'v2.1.0' when directly on tag
        if re.match(self.devTagFormat, description):
            assert not self.onMasterBranch(), "Got dev tag but on master branch - forgot to set release tag?"
            tagName = re.search(self.devTagFormat, description).group()
        elif re.match(self.releaseTagFormat, description):
            assert self.onMasterBranch(), "Got release tag but on dev branch - forgot to set \"dev0\"-tag?"
            tagName = re.search(self.releaseTagFormat, description).group()
        else:
            tagName = None

        # Try to find a tag that matches the name
        for tag in self.repo.tags:
            if tag.name == tagName:
                return tag
        raise Exception("Unable to find git tag that matches describe output")

    def getDevTagNumber(self, tag):
        """
        Get the dev tag number, e.G. v2.1.0-dev13 will result in 13
    
        :param tag: Tag the number should be parsed of
        :return: The dev tag number parsed from the dev tag.
        """
        assert re.match(self.devTagFormat, tag.name)
        return int(re.findall(r'\d+', tag.name)[-1])

    def getCommitsSinceLastTag(self):
        """
        Get the number of commits since the last tag was set.

        The format of the tag is specified by getLastTag().
    
        :param tag: the tag to start counting from.
        :return: The number of commits since the last tag.
        """
        lastTagCommitHash = self.getLastTag()._get_commit().hexsha
        currentCommitHash = self.repo.head.commit.hexsha
        return int(self.repo.git.rev_list('--count', f'{lastTagCommitHash}..{currentCommitHash}'))

    def createDevTag(self):
        """
        Create a new dev tag with a new number in the local repository.
    
        Will abort when not on a dev branch (name must be "dev_vA.B.C").
        Will only set a dev tag if there is not already one set on the current commit.
        Requires presence of "dev0"-tag on first dev branch commit (create it manually!).
        The dev tag number is the previous dev tag number increased by the number of commits
        since the last dev tag was set.
        
        :return: The new tag as an object. No need to use it.
        """
        if not self.onDevBranch():
            sys.exit("Trying to create dev tag outside of dev branch, abort")
        else:
            lastTag = self.getLastTag()
            lastDevTagNumber= self.getDevTagNumber(lastTag)
            lastTagCommitHash = lastTag._get_commit().hexsha
            currentCommitHash = self.repo.head.commit.hexsha
            newTag = None

            # Do not set multiple dev tags on a single commit
            if lastTagCommitHash != currentCommitHash:
                # Create a new tag increased by the number of commits since last tag and generate project version string
                latestDevTagVersion = re.search(self.versionFormat, lastTag.name).group()
                newDevTagName = latestDevTagVersion + "-dev" + str(lastDevTagNumber + self.getCommitsSinceLastTag())
                try:
                    newTag = git.Tag.create(self.repo, newDevTagName, self.repo.head.commit,
                                            "Tag created automatically by flasher build process")
                except:
                    sys.exit(f'Could not create tag \"{newDevTagName}\" on commit \"{currentCommitHash}\"')
            return newTag

    def getVersionNumber(self):
        """"
        Get the version number of the previous tag (e.g. "v2.1.0")
    
        Aborts if the version can not be parsed.

        :return: The version number of the last git tag.
        """
        assert re.match(self.versionFormat, self.getLastTag().name), "Invalid format of last git tag"
        return re.search(self.versionFormat, self.getLastTag().name).group()

    def getDevEnding(self):
        """
        Get the dev ending including commits since the last tag and the "repo-dirty"-"+".
    
        Will omit "-devA" when on master branch (release)
        "-devA-B+"
        A = dev version from tag
        B = commits since last tag
        + : optional - will appear when the repo is dirty

        :return: The dev ending depending on the current branch.
        """
        if self.onMasterBranch():
            ending = ""
        else:
            ending = "-dev" + str(self.getDevTagNumber(self.getLastTag()))
        ending += "-" + str(self.getCommitsSinceLastTag()) 
        ending += "+" if self.repo.is_dirty() else ""
        return ending

    def getFullVersionString(self):
        """
        Get the full Version string, format:
    
        vA.B.C-devD+-E-gHASH
        A.B.C = flasher version
        D = dev tag version
        E = commits since last tag
        + : optional - will appear when the repo is dirty
        HASH = shortened git hash of the current commit (optional when on dev branch or in detached head state)

        :return: The full version string consisting out of version number, dev Ending and the last 7 commit hash chars.
        """
        name = self.getVersionNumber()
        name += self.getDevEnding()
        
        # If not on master or dev branch, also append the commit hash
        if not self.onMasterBranch() and not self.onDevBranch():
            name += "g" + str(self.repo.head.commit.hexsha)[:7]
        return name
