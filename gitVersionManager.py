import git
import re
import sys

# Class for managing git tags and getting version strings in the flasher and romloader repo
class gitVersionManager:
    versionFormat = r"v\d+\.\d+\.\d+"
    devBranchFormat = r"^dev_v\d+\.\d+\.\d+$"
    devTagFormat = r"v\d+\.\d+\.\d+-dev\d+"
    releaseTagFormat = versionFormat


    # Creates a gitVersionManager Object
    #
    # strRepoPath = path the current repo is in (use "/" for dirs, "." for current dir)
    def __init__(self, strRepoPath):
        self.repo = git.Repo(strRepoPath)


    # Checks if current branch is a dev branch (matches the pattern "dev_vX.Y.Z", e.g. dev_v2.1.0)
    def onDevBranch(self):
        return bool(re.match(self.devBranchFormat, self.getCurrentBranch().name))


    # Checks if the current branch is the master branch
    def onMasterBranch(self):
        return self.getCurrentBranch().name == "master"


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


    # Gets the last tag from "git describe"-output
    #
    # Note that tags will be inherited when merging.
    # When merging to master, create a release version tag ("vA.B.C")
    # Only works with:
    # dev-tags:     "vA.B.C-devD"
    # release-tags: "vA.B.C"
    # Aborts if other tag is found or branch-tag combination is invalid.
    def getLastTag(self):
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
        sys.exit("Unable to find git tag that matches describe output")


    # Gets the dev tag number, e.G. v2.1.0-dev13 will result in 13
    #
    # tag: tag the number should be parsed of
    def getDevTagNumber(self, tag):
        assert re.match(self.devTagFormat, tag.name)
        return int(re.findall(r'\d+', tag.name)[-1])


    # Gets the number of commits since the tag was set
    #
    # tag: the tag to start counting from
    def getCommitsSinceLastTag(self):
        lastTagCommitHash = self.getLastTag()._get_commit().hexsha
        currentCommitHash = self.repo.head.commit.hexsha
        return int(self.repo.git.rev_list('--count', f'{lastTagCommitHash}..{currentCommitHash}'))


    # Creates a new dev tag with a new number
    # 
    # Will abort when not on a dev branch (name must be "dev_vA.B.C").
    # Will only set a dev tag if there is not already one set on the current commit.
    # Requires presence of "dev0"-tag on first dev branch commit (create it manually!).
    # The dev tag number is the previous dev tag number increased by the number of commits
    # since the last dev tag was set.
    def createDevTag(self):
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
                    newTag = git.Tag.create(self.repo, newDevTagName, self.repo.head.commit, "Tag created automatically by flasher build process")
                except:
                    sys.exit(f'Could not create tag \"{newDevTagName}\" on commit \"{currentCommitHash}\"')
            return newTag


    # Get the version number of the previous tag (e.g. "v2.1.0")
    #
    # Aborts if the version can not be parsed.
    def getVersionNumber(self):
        assert re.match(self.versionFormat, self.getLastTag().name), "Invalid format of last git tag"
        return re.search(self.versionFormat, self.getLastTag().name).group()


    # Get the dev ending including commits since the last tag and the "repo-dirty"-"+".
    #
    # Will omit "-devA" when on master branch (release)
    # "-devA-B+"
    # A = dev version from tag
    # B = commits since last tag
    # + : optional - will appear when the repo is dirty
    def getDevEnding(self):
        if self.onMasterBranch():
            ending = ""
        else:
            ending = "-dev" + str(self.getDevTagNumber(self.getLastTag()))
        ending += "-" + str(self.getCommitsSinceLastTag()) 
        ending += "+" if self.repo.is_dirty() else ""
        return ending


    # Get the full Version string, format:
    #
    # vA.B.C-devD+-E-gHASH
    # A.B.C = flasher version
    # D = dev tag version
    # E = commits since last tag
    # + : optional - will appear when the repo is dirty
    # HASH = shortened git hash of the current commit
    def getFullVersionString(self):
        name = self.getVersionNumber()
        name += self.getDevEnding()
        name += "g" + str(self.repo.head.commit.hexsha)[:7]
        return name