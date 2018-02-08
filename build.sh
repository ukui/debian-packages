#!/bin/dash
debian_src="debian-packages"
def_list="ukui-menus ukui-panel ukui-menu ukui-session-manager peony ukui-screensaver ukui-indicators ukui-control-center kylin-burner kylin-video peony-extensions"
all_list=`ls -d */`
all_list=`echo $all_list | sed 's/\///g'`
old_user=`whoami`
password="123"

mk_build_deps() {
sudo -S su << EOF 
$password
yes Y | mk-build-deps -i $@
if [ $? = 0 ]; then
    echo "mk-build-deps $@ successed!"
else
    echo "mk-build-deps $@ error!"
fi
su $old_user
EOF
}

clone() {
    if [ $@ != "def" ]; then
        def_list=$@
    fi
    for package in $def_list; do
        git clone git@github.com:ukui/$package
    done
}

tar_orig() {
    packages=$@
    for file in $packages
    do
        if [ -e $debian_src/$file/debian/changelog ]
        then
            changelog=`head -1 $debian_src/$file/debian/changelog`
            tmp="${changelog##*(}"
            version="${tmp%%-*}"
            echo "$file version is $version"
        else
            continue
        fi
        tar -czf $file\_$version.orig.tar.gz --exclude=.git --exclude=.bzr $file
        echo "tar '$file' successed"
    
        cp -r $debian_src/$file/debian $file
        echo "cp '$debian_src'/$file/debian to '$file'"
    done 
}

install_depends() {
    packages=$@
    for file in $packages
    do
        if [ -e $file/debian/control ]
        then
            mk_build_deps $file/debian/control
        else
            continue
        fi
    done
}

build() {
    if [ $@ = "all" ]; then
        packages=$all_list
    elif [ $@ = "def" ]; then
        packages=$def_list
    else
        packages=$@
    fi
    tar_orig $packages
    install_depends $packages
    for file in $packages
    do
        if [ $file != ${debian_src} ]
        then
            cd $file
            debuild
            if [ $? = 0 ]; then
                echo "debuild $file successd!"
            else
                echo "debuild $file faild!"
                cd ..
                exit 1
            fi
            cd ..
        fi
    done
}

clean () {
    if [ $@ = "all" ]; then
        packages=$all_list
    elif [ $@ = "def" ]; then
        packages=$def_list
    else
        packages=$@
    fi
    for file in $packages
    do
        cd $file
        git clean -df
        if [ $? = 0 ]; then
            echo "clean $file successd!"
        else
            echo "error when clean $file"
            exit 1;
        fi
        cd ..
    done
}

pull () {
    if [ $@ = "all" ]; then
        packages=$all_list
    elif [ $@ = "def"]; then
        packages=$def_list
    else
        packages=$@
    fi
    for file in $packages
    do
        cd $file
        git pull
        if [ $? = 0 ]; then
            echo "Pull $file successd!"
        else
            echo "Error when pull $file"
            exit 1;
        fi
        cd ..
    done
}

install() {
sudo -S su << EOF 
$password
dpkg -i *.deb
su $old_user
EOF
}

usage() {
    echo "****************************************************************"
    echo "This is the build tool for UKUI!"
    echo "Usage: ./build.sh [-h] [-b <package>] [-c <package>]"
    echo "                  [-g <pakcage>] [-i <package>] [-p <package>]"
    echo "       all:" $all_list
    echo "       def:" $def_list
    echo "       -b all | def | <package> : build package"
    echo "       -c def |       <package> : git clean"
    echo "       -g all | def | <package> : git clone"
    echo "       -h all | def | <package> : show this help info"
    echo "       -i all | def | <package> : dpkg -i *.deb"
    echo "       -p all | def | <package> : git pull"
    echo "****************************************************************"
}

while getopts :b:c:g:hi:p: opt
do
    case "$opt" in
    b) build $OPTARG ;;
    c) clean $OPTARG ;;
    g) clone $OPTARG ;;
    h) usage $OPTARG ;;
    i) install $OPTARG ;;
    p) pull  $OPTARG;;
    :) echo "Error: the option -$OPTARG requres an argument." 
       usage ;;
    ?) echo "Error: invalid option: -$OPTARG"
       usage ;;
    esac
done
