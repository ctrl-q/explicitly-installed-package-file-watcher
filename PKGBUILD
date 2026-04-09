pkgname=explicit-package-file-watcher
pkgver=0.0.1
pkgrel=1
arch=('any')
depends=('coreutils' 'findutils' 'gawk' 'grep' 'inotify-tools')
source=('main.sh')
sha512sums=('SKIP')

package(){
	install -d "${pkgdir}/usr/local/bin"
	ln -s "$(dirname ${srcdir})/main.sh" "${pkgdir}/usr/local/bin/${pkgname}"
}

