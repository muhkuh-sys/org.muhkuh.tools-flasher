import groovy.json.JsonSlurperClassic

node {
    /* Path to the CLI flasher packages */
    def ARTIFACTS_PATH1 = 'flasher-environment/build/artifacts'
    /* Path to the flasher binaries */
    def ARTIFACTS_PATH2 = 'targets/jonchki/repository/org/muhkuh/tools/flasher/*'
    def strBuilds = env.JENKINS_SELECT_BUILDS
    def atBuilds = new JsonSlurperClassic().parseText(strBuilds)

    atBuilds.each { atEntry ->
        stage("${atEntry[0]} ${atEntry[1]} ${atEntry[2]}"){

            docker.image("${atEntry[3]}").inside('-u root') {
                /* Clean before the build. */
                sh 'rm -rf .[^.] .??* *'
        
                checkout([$class: 'GitSCM',
                    branches: [[name: env.GIT_BRANCH_SPECIFIER]],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [
                        [$class: 'SubmoduleOption',
                            disableSubmodules: false,
                            recursiveSubmodules: true,
                            reference: '',
                            trackingSubmodules: false
                        ]
                    ],
                    submoduleCfg: [],
                    userRemoteConfigs: [[url: 'https://github.com/muhkuh-sys/org.muhkuh.tools-flasher.git']]
                ])
        
                /* Build the project (includes flasher binary and other 
                   components like romloader etc. */
                sh "./build_artifact.py ${atEntry[0]} ${atEntry[1]} ${atEntry[2]}"
        
                /* Archive all artifacts. */
                archiveArtifacts artifacts: "${ARTIFACTS_PATH1}/*.tar.gz,${ARTIFACTS_PATH1}/*.zip,${ARTIFACTS_PATH2}/*.hash,${ARTIFACTS_PATH2}/*.pom,${ARTIFACTS_PATH2}/*.xml,${ARTIFACTS_PATH2}/*.zip"
        
                /* Clean up after the build. */
                sh 'rm -rf .[^.] .??* *'
            }
        }
    }
}
