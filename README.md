# new (*N*eovim *E*xpect *W*indow)
A state terminal window manager with tcl-expect-like supported for nvim which base on:
- https://github.com/paroxayte/vwm.vim
- https://github.com/neovim/neovim/blob/master/contrib/gdb/neovim_gdb.vim

## Features

* Save and manage vim windows via layouts
* Automatically cache and unlist buffers
* Automatically reuse buffers
* Regroup command buffers
* Highly configurable

## Installation

* **vimplug:** `Plug 'huawenyu/new.vim'`
* **dein:** `call dein#add('huawenyu/new.vim')`
* **manual:** source the this repo to your vim runtime

## Usage

* **Layout on:**      `:NewOpen *layout_name*`
* **Layout off:**     `:NewClose *layout_name*`
* **Layout toggle:**  `:NewToggle *layout_name*`

*note:* `default` *is the only default layout. Test it out!*

## Examples

### Plugin list:
- Vim GDB front-end for neovim: https://github.com/huawenyu/new-gdb.vim

**_note:_** For detailed configuration see `help: new.vim`.

