pipeline {
    agent any

    stages {
        stage('Show Info') {
            steps {
                echo 'Branch: ' + env.GIT_BRANCH
                echo 'Author: ' + sh(returnStdout: true, script: "git --no-pager show -s --format='%an'").trim()
            }
        }
    }

}
