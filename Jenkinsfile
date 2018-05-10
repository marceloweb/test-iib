node('master'){
    stage('Prepare'){
        customWorkspace "$JENKINS_HOME/workspace/test-iib"
    }

    stage('Clean'){
        deleteDir()
        sh 'ls -la'
    }

    stage('Fetch') {
        checkout scm
    }

    stage('Build'){
        sh 'ant deploy'
    }

}
