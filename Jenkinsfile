node('master'){

    stage('Clean'){
        deleteDir()
        sh 'ls -la'
    }

    stage('Fetch') {
        checkout scm
    }

    stage('Prepare'){
        sh 'cp -R $JOB_NAME test-iib'
    }

    stage('Build'){
        sh 'ant deploy'
    }

}
