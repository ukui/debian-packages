#!/bin/dash
debian_src="debian-packages"
package_list="ukui-menus ukui-panel ukwm ukui-settings-daemon ukui-power-manager ukui-media ukui-window-switch kylin-burner kylin-video peony-extensions"
old_user=`whoami`
password="123123"

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

#option "$@"
option() {
    for tm in $@
    do
        arg=$1
        case $arg in
        -c|--clone)
            clone
            shift
            [ -z $@ ] && exit 0
            ;;
        -b|--build)
            build
            shift 1
            [ -z $@ ] && exit 0
            ;;
        -h|--help)
            echo "The build tools for UKUI"
            exit 1
            ;;
        *)
            echo "Unknow args!"
            exit 2
            ;;
        esac
    done
}

clone() {
    if [ $@ != "all" ]; then
        package_list=$@ 
    fi
    for package in $package_list; do
        git clone git@github.com:ukui/$package 
    done
}

tar_orig() {
    packages=$@
    for file in $packages
    do
        file=${file%%/}
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
        file=${file%%/}
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
        packages=`ls -d */`
    else
        packages=$@
    fi
    tar_orig $packages
    install_depends $packages
    for file in $packages
    do
        file=${file%%/}
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
        packages=`ls -d */`
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
    echo "Usage: ./build.sh [-h] [-b <packages>] [-c <packages>]"
    echo "                  [-g <pakcages>] [-i <packages>]"
    echo "  -b all | <packages> :build packages"
    echo "  -c all | <packages> :removing files that are not under version control"
    echo "  -g all | <packages> :git clone packages: $package_list"
    echo "  -h all | <packages> :show this help info"
    echo "  -i all | <packages> :install all the deb packages in current dir"
    echo "****************************************************************"
}

while getopts :b:c:g:hi: opt
do
    case "$opt" in
    b) build $OPTARG ;;
    c) clean $OPTARG ;;
    g) clone $OPTARG ;;
    h) usage $OPTARG ;;
    i) install $OPTARG ;;
    :) echo "Error: the option -$OPTARG requres an argument." 
       usage ;;
    ?) echo "Error: invalid option: -$OPTARG"
       usage ;;
    esac
done
