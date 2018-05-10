node('master'){

    stage('Clean'){
        deleteDir()
        sh 'ls -la'
    }

    stage('Fetch') {
        checkout scm
    }

    stage('Prepare'){
        sh 'cp -R $JENKINS_HOME/workspace/$JOB_NAME $JENKINS_HOME/workspace/test-iib'
    }

    stage('Build'){
        sh 'ant deploy'
    }

}
