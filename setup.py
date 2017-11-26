import setuptools
import sys
import os

from numpy.distutils.core import setup
from numpy.distutils.misc_util import Configuration
from numpy.distutils.system_info import default_include_dirs, default_lib_dirs

from Cython.Build import cythonize


def configuration(parent_package='', top_path=None):
    """Configure all packages that need to be built."""
    config = Configuration('', parent_package, top_path)

    if sys.platform == 'win32':
        libraries = ["flint", "arb", "mpir", "mpfr", "pthreads"]
    else:
        libraries = ["flint", "arb"]

    # Collect all Cython sources
    files = os.listdir('src')
    sources = [
        os.path.join('src', file) for file in files
        if file.lower().endswith('.pyx')
    ]

    sources = [os.path.join('src', 'pyflint.pyx')]

    include_path = default_include_dirs + ['src']
    sources = cythonize(sources, include_path=include_path)

    # FLINT
    config.add_extension(
        'flint',
        libraries=libraries,
        sources=sources,
        include_dirs=include_path,
        library_dirs=default_lib_dirs)

    return config


setup(
    name='python-flint',
    description='bindings for FLINT',
    url='https://github.com/python-flint/python-flint',
    author='Fredrik Johansson',
    author_email='fredrik.johansson@gmail.com',
    license='BSD',
    platforms='OS Independent',
    packages=setuptools.find_packages(),
    setup_requires=['setuptools_scm'],
    use_scm_version=True,
    classifiers=['Topic :: Scientific/Engineering :: Mathematics'],
    configuration=configuration)