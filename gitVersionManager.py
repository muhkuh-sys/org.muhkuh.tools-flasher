import re
import sys
try:
    import git
except:
    raise ImportError("Module gitpython missing, install using \"pip install gitpython\"")

# Class for managing git tags and getting version strings in the flasher and romloader repo
class gitVersionManager:
    versionFormat = r"v\d+\.\d+\.\d+"
    devBranchFormat = r"^dev_v\d+\.\d+\.\d+$"
    devTagFormat = r"v\d+\.\d+\.\d+-dev\d+"
    releaseTagFormat = versionFormat
    releaseBranchNames = ["master", "HEAD"]


    # Creates a gitVersionManager Object
    #
    # strRepoPath = path the current repo is in (use "/" for dirs, "." for current dir)
    def __init__(self, strRepoPath, repo_nickname=""):
        self.repo = git.Repo(strRepoPath)
        self.repo_nickname = repo_nickname


    # Gets the branch the repository is currently on.
    #
    # Detached Head state is tricky. Will return the first found branch the current commit is on.
    def getCurrentBranch(self):
        # Try to get the current branch, if the head is detached, look for a branch containing the current commit
        currentCommit = self.repo.head.commit
        if self.repo.head.is_detached:
            for branch in self.repo.remotes["origin"].refs:
                if self.repo.is_ancestor(currentCommit, branch.commit)\
                    or currentCommit == branch.commit:
                    return branch
        else:
            return self.repo.active_branch


    # Gets the current branch name
    def getCurrentBranchName(self):
        branch = self.getCurrentBranch()
        # Remove "origin/" if present
        if "/" in branch.name:
            return str.split(branch.name, "/")[-1]
        print(f"({self.repo_nickname})current branch name: {branch.name}")
        return branch.name


    # Checks if current branch is a dev branch (matches the pattern "dev_vX.Y.Z", e.g. dev_v2.1.0)
    def onDevBranch(self):
        return bool(re.match(self.devBranchFormat, self.getCurrentBranchName()))


    # Checks if the current branch is the release branch
    def onReleaseBranch(self):
        current_branch_name = self.getCurrentBranchName()
        return current_branch_name in self.releaseBranchNames

    # Gets the last tag from "git describe"-output
    #
    # Note that tags will be inherited when merging.
    # When merging to release branch, create a release version tag ("vA.B.C")
    # Only works with:
    # dev-tags:     "vA.B.C-devD"
    # release-tags: "vA.B.C"
    # Aborts if other tag is found or branch-tag combination is invalid.

    def getLastTag(self):
        # Get the git describe output, gitpython has no good way of providing the tag
        description = self.repo.git.describe()  # e.g. 'v2.1.0-dev13-15-gb39e454' or 'v2.1.0' when directly on tag
        print(f"({self.repo_nickname})git describe: {description}")
        if re.match(self.devTagFormat, description):
            assert not self.onReleaseBranch(), "Got dev tag but on release branch - forgot to set release tag?"
            tagName = re.search(self.devTagFormat, description).group()
        elif re.match(self.releaseTagFormat, description):
            assert self.onReleaseBranch(), "Got release tag but on dev branch - forgot to set \"dev0\"-tag?"
            tagName = re.search(self.releaseTagFormat, description).group()
        else:
            tagName = None

        # Try to find a tag that matches the name
        for tag in self.repo.tags:
            if tag.name == tagName:
                return tag
        sys.exit("Unable to find git tag that matches describe output")


    # Gets the dev tag number
    # 
    # e.G. v2.1.0-dev13 will result in 13
    #
    # tag: tag the number should be parsed of
    def getDevTagNumber(self, tag):
        assert re.match(self.devTagFormat, tag.name)
        return int(re.findall(r'\d+', tag.name)[-1])


    # Gets the number of commits made since the tag was set
    #
    # tag: the tag to start counting from
    def getCommitsSinceLastTag(self):
        lastTagCommitHash = self.getLastTag()._get_commit().hexsha
        currentCommitHash = self.repo.head.commit.hexsha
        return int(self.repo.git.rev_list('--count', '--ancestry-path', f'{lastTagCommitHash}..{currentCommitHash}'))


    # Creates a new dev tag with a new number (vA.B.C-devD)
    # 
    # Will abort when not on a dev branch (name must be "dev_vA.B.C").
    # Will abort if there is a tag already set on the current commit.
    # Requires presence of "dev0"-tag on (first) dev branch commit (create it manually!).
    # The dev tag number (D) is the previous dev tag number increased by the number of 
    # commits since the last dev tag was set.
    def createDevTag(self):
        assert self.onDevBranch(), "Trying to create dev tag outside of dev branch, abort"
        lastTag = self.getLastTag()
        lastDevTagNumber= self.getDevTagNumber(lastTag)
        lastTagCommitHash = lastTag._get_commit().hexsha
        currentCommitHash = self.repo.head.commit.hexsha
        newTag = None

        # Do not set multiple dev tags on a single commit
        assert lastTagCommitHash != currentCommitHash, "Tag already exists on current commit"

        # Create a new tag increased by the number of commits since last tag and generate the project version string
        latestDevTagVersion = re.search(self.versionFormat, lastTag.name).group()
        newDevTagName = latestDevTagVersion + "-dev" + str(lastDevTagNumber + self.getCommitsSinceLastTag())

        # Try to create the git tag on the current commit
        try:
            newTag = git.Tag.create(self.repo, newDevTagName, self.repo.head.commit, "Tag created automatically by flasher build process")
        except:
            sys.exit(f'Could not create tag \"{newDevTagName}\" on commit \"{currentCommitHash}\"')
        return newTag

    # Gets the version number of the last tag (e.g. "v2.1.0")
    #
    # Aborts if there is no version in the last tag.


    def getVersionNumber(self):
        last_git_tag_name = self.getLastTag().name
        print(f"Last git tag name: {last_git_tag_name}")
        assert re.match(self.versionFormat, last_git_tag_name), "Invalid format of last git tag"
        return re.search(self.versionFormat, last_git_tag_name).group()

    # Gets the dev ending
    #
    # When on release branch:
    # ""   when the current commit is the release tag commit
    # "-X" when there were X commits since the last release tag
    #
    # When not on release branch:
    # "-devA-B+"
    # A = dev version from tag
    # B = commits since last tag
    # + : optional - will appear when the repo is dirty
    def getDevEnding(self):
        if self.onReleaseBranch():
            ending = ""
            if(self.getCommitsSinceLastTag() > 0):
                ending += "-" + str(self.getCommitsSinceLastTag())
        else:
            ending = "-dev" + str(self.getDevTagNumber(self.getLastTag()))
            ending += "-" + str(self.getCommitsSinceLastTag()) 
        return ending

    # Get the full Version string suitable for the current branch
    #
    # dev-branch or release branch: 
    #  version + dev ending (from getDevEnding())
    #  vA.B.C-devD-E
    # 
    # other (e.g. feature branch):
    #  version + "-" + branch name + "-g" + short commit hash + repo-dirty-"+"
    #  vA.B.C-BRANCH-gHASH+
    # 
    # A.B.C = flasher version
    # D = dev tag version
    # E = commits since last tag (optional)
    # + : optional - inserted when the repo is dirty
    # HASH = shortened git hash of the current commit
    def getFullVersionString(self):
        name = self.getVersionNumber()
        print(f"({self.repo_nickname})getFullVersionString: {name}")
        if self.onDevBranch() or self.onReleaseBranch():
            name += self.getDevEnding()
        else:
            name += "-" + self.getCurrentBranchName()
            name += "-g" + str(self.repo.head.commit.hexsha)[:7]
            name += "+" if self.repo.is_dirty() else ""
        return name


if __name__ == '__main__':
    repoManager = gitVersionManager(".")
    if repoManager.onDevBranch() or repoManager.onReleaseBranch():
        build_type = repoManager.getDevEnding()
    else:
        build_type = "-" + repoManager.getCurrentBranchName()

    # Set the artifact name
    strMbsProjectVersion = repoManager.getFullVersionString()
    print("")
