#!/bin/sh
# Gradle Wrapper launcher for KOMBAX / Urban Warriors.
# Wrapper runtime: Gradle 8.11.1 (configured in gradle/wrapper/gradle-wrapper.properties).

APP_PATH=$0
while [ -h "$APP_PATH" ]; do
    LS=$(ls -ld "$APP_PATH")
    LINK=${LS#*' -> '}
    case $LINK in
        /*) APP_PATH=$LINK ;;
        *) APP_PATH=$(dirname "$APP_PATH")/$LINK ;;
    esac
done
APP_HOME=$(cd -P "$(dirname "$APP_PATH")" >/dev/null 2>&1 && pwd) || exit 1
APP_BASE_NAME=${0##*/}
CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar

if [ -n "$JAVA_HOME" ]; then
    JAVACMD="$JAVA_HOME/bin/java"
    if [ ! -x "$JAVACMD" ]; then
        echo "ERROR: JAVA_HOME is set to an invalid directory: $JAVA_HOME" >&2
        echo "Please set JAVA_HOME to a JDK 17 installation." >&2
        exit 1
    fi
else
    JAVACMD=java
    if ! command -v java >/dev/null 2>&1; then
        echo "ERROR: JAVA_HOME is not set and no java command was found in PATH." >&2
        echo "Please install JDK 17 or set JAVA_HOME to a JDK 17 installation." >&2
        exit 1
    fi
fi

exec "$JAVACMD" \
    -Dfile.encoding=UTF-8 \
    -Xmx64m -Xms64m \
    ${JAVA_OPTS:-} ${GRADLE_OPTS:-} \
    "-Dorg.gradle.appname=$APP_BASE_NAME" \
    -classpath "$CLASSPATH" \
    org.gradle.wrapper.GradleWrapperMain "$@"
