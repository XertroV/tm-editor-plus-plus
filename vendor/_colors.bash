#!/usr/bin/env bash
################################################################################
#                                                                              #
#                                                                              #
#  | (_) |__   ___ ___ | | ___  _ __ ___  | |__   __ _ ___| |                  #
#  | | | '_ \ / __/ _ \| |/ _ \| '__/ __| | '_ \ / _` / __| '_ \               #
#  | | | |_) | (_| (_) | | (_) | |  \__ \_| |_) | (_| \__ \ | | |              #
#  |_|_|_.__/ \___\___/|_|\___/|_|  |___(_)_.__/ \__,_|___/_| |_|              #
#                                                                              #
#  This color library uses 16 basic foreground and 16 basic background colors. #
#  This gives 16*16 possible combinations, or 256 possible color combinations. #
#  With 6 text effects the combinations go to 1536 possible combinations.      #
#  Granted, some combinations would be hideous and never used.                 #
#                                                                              #
#  Also included are a selection of tput colors for displays that can handle   #
#  more colors.  See more tput colors you can add by running the function      #
#  _colortable. Run the function _howmanycolors to see how many colors your    #
#  terminal supports.                                                          #
#                                                                              #
  __libcolor_bashversion="0.0.1.45"                                            #
#                                                                              #
# Change History                                                               #
# 01/14/2021        initial version                                            #
# 01/23/2021        added tput colors                                          #
# 01/27/2021        added ESC variable, _howmanycolors                         #
# 02/25/2021        all non-environment vars to lowercase                      #
# 03/05/2021        resetbold is not working, added italics                    #
#                                                                              #
# -----------------------------------------------------------------------------#
# DATE:         Thu 14 Jan 2021 02:39:03 AM MST                                #
# AUTHOR:       Bob Franklin-Furter                                            #
# LICENSE:      GNU General Public License                                     #
# BASH_VERSION: 5.0.17(1)-release                                              #
# ZSH_VERSION:  zsh 5.8                                                        #
# -----------------------------------------------------------------------------#
################################################################################
################################################################################
################################################################################
#                                                                              #
#  Copyright (c) 2021, Bob Franklin-Furter                                     #
#                                                                              #
#  This program is free software; You can redistribute it and/or modify        #
#  it under the terms of the GNU General Public License as published by        #
#  the Free Software Foundation; either version 2 of the License, or           #
#  (at your option) any later version.                                         #
#                                                                              #
#  This program is distributed in the hope that it will be useful,             #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of              #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
#  GNU General Public License for more details.                                #
#                                                                              #
#  You should have received a copy of the GNU General Public License           #
#  along with this program; if not, write to the Free Software                 #
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA     #
#                                                                              #
################################################################################
################################################################################
################################################################################
#  USAGE:
#
#  You first need to source the script in your own bash script. I prefers to
#  use a dot, then the full path to the libcolor.bash file:
#
#            . $HOME/bin/library.bash/libcolor.bash
#
#  Or, you can put the file your $PATH file, or in a location already in
#  your $PATH.  In that case all you would need to do is:
#
#  . libcolor.bash
#
#  You can:
#          1. Directly use the colors in your own script like this.
#             Use the -e swtich:
#
#             echo -e "${blue}This is blue text${resetall}"
#
#          2. Use the available 3 functions to color your text:
#
#             _colortext16 red "This is red text."
#             _colortext16 blue "${blink}The blue text blinks."
#             _colortext16 "magenta" "Magenta text."
#
#             _colorbackground16 green "This text has a green background."
#             _colorbackground16 yellow "${underline}Underlined yellow text."
#             _colorbackground16 "blue" "Blue text is neat."
#
#             _colorfgbg green cyan "Green text with cyan background is ugly."
#             _colorfgbg "yellow" "red" "Yellow text in a red background."
#
#	   3. echo "${tblue}This text is tput blue.${tresetall}"
#	      echo "${tblue_bg}${tgold}Nice Comination.${tresetall}"
#
#
#  There is a great bash script to figure out how many colors your terminal
#  supports.  I have nothing to do with this script.  You can download it at:
#
#  https://github.com/l0b0/xterm-color-count/find/master
#
# DEPENDENCIES: none, other than bash (works in zsh too)
#
# ==============================================================================
#
#  INSTALL DEPENDENCIES:
#
#     Ubuntu/LinuxMint (other distributions will differ)
#
# ==============================================================================
# TODO: add more colors
# TODO: check how many colors the terminal supports
# TODO: check for ncurses (tput command). Add tput colors if ncurses installed
# TODO: add functions to check shell compatibility
################################################################################

{ # bottom bracket must exist for this code to execute. This helps prevent
  # executing a partially downloaded script.

  __fgbg="0"  #flag for combining fg and bg functions

  #\e, \033, \x1B are all valid escape codes. I use \e in this script.
  readonly    esc1="\e["
  readonly    esc2="\033["
  readonly    esc3="\x1B[" #use this for Mac OS

  readonly    resetall="${esc1}0m"         #resets ALL attributes
  readonly    resetfg="${esc1}39m"         #resets foreground color only
  readonly    resetbg="${esc1}49m"         #resets background color only

  #*************************
  #*     Text effects      *
  #*************************

  # resets have a 2 in front of the regular number
  readonly    bold="${esc1}1m"
  #resetbold not working. Use resetall to clear bold.
  #readonly    resetbold="${esc1}21m"

  readonly    dim="${esc1}2m"
  readonly    resetdim="${esc1}22m"

  readonly    italics="${esc1}3m"
  readonly    resetitalics="${esc1}23m"

  readonly    underline="${esc1}4m"
  readonly    resetunderline="${esc1}24m"

  readonly    blink="${esc1}5m"
  readonly    resetblink="${esc1}25m"

  readonly    reverse="${esc1}7m"
  readonly    resetreverse="${esc1}27m"

  readonly    hidden="${esc1}8m"
  readonly    resethidden="${esc1}28m"

  # the following colors work with most terminals.
  # for compatibility see:
#https://misc.flogisoft.com/bash/tip_colors_and_formatting#terminals_compatibility

  #****************************
  #* Foreground colors (text) *
  #****************************

  # 8 foreground colors
  readonly    black="${esc1}30m"
  readonly    red="${esc1}31m"
  readonly    green="${esc1}32m"
  readonly    yellow="${esc1}33m"
  readonly    blue="${esc1}34m"
  readonly    magenta="${esc1}35m"
  readonly    cyan="${esc1}36m"
  readonly    lightgrey="${esc1}37m"

  #8 more foreground colors (16 total)
  readonly    darkgrey="${esc1}90m"
  readonly    lightred="${esc1}91m"
  readonly    lightgreen="${esc1}92m"
  readonly    lightyellow="${esc1}93m"
  readonly    lightblue="${esc1}94m"
  readonly    lightmagenta="${esc1}95m"
  readonly    lightcyan="${esc1}96m"
  readonly    white="${esc1}97m"

  #*************************
  #*   Background colors   *
  #*************************

  #8 background colors
  readonly    black_bg="${esc1}40m"
  readonly    red_bg="${esc1}41m"
  readonly    green_bg="${esc1}42m"
  readonly    yellow_bg="${esc1}43m"
  readonly    blue_bg="${esc1}44m"
  readonly    magenta_bg="${esc1}45m"
  readonly    cyan_bg="${esc1}46m"
  readonly    lightgrey_bg="${esc1}47m"

  #8 more background colors (16 total)
  readonly    darkgrey_bg="${esc1}100m"
  readonly    lightred_bg="${esc1}101m"
  readonly    lightgreen_bg="${esc1}102m"
  readonly    lightyellow_bg="${esc1}103m"
  readonly    lightblue_bg="${esc1}104m"
  readonly    lightmagenta_bg="${esc1}105m"
  readonly    lightcyan_bg="${esc1}106m"
  readonly    white_bg="${esc1}107m"

  #combinations. use directly
  readonly    red_bold=${red}${bold}
  readonly    blue_bold=${blue}${bold}
  readonly    green_bold=${green}${bold}

  #*************************
  #*       Functions       *
  #*************************

  _libcolor_version() {

  echo "${tgreen_bold}libcolor.bash${tresetall} - version: \
  ${__libcolor_bashversion}"

  }

  _colortext16() {

  if [[ "$#" -eq 0  || "$#" -gt 2 ]]; then return
  fi

  __textcolor=${1:-}  #don't make this local. it is used elsewhere
  local __text=${2:-}

  case ${__textcolor} in

     "black")     __textcolor=${black}
                  ;;
     "red")       __textcolor=${red}
                  ;;
     "green")     __textcolor=${green}
                  ;;
     "yellow")    __textcolor=${yellow}
                  ;;
     "blue")      __textcolor=${blue}
                  ;;
     "magenta")   __textcolor=${magenta}
                  ;;
     "cyan")      __textcolor=${cyan}
                  ;;
     "lgrey")     __textcolor=${lightgrey}
                  ;;
     "dgrey")     __textcolor=${darkgrey}
                  ;;
     "lred")      __textcolor=${lightred}
                  ;;
     "lgreen")    __textcolor=${lightgreen}
                  ;;
     "lyellow")   __textcolor=${lightyellow}
                  ;;
     "lblue")     __textcolor=${lightblue}
                  ;;
     "lmagenta")  __textcolor=${lightmagenta}
                  ;;
     "lcyan")     __textcolor=${lightcyan}
                  ;;
     "white")     __textcolor=${white}
                  ;;
            *)    echo -ne "${red_bg}Unknown text color:${resetall}"
                  ;;
  esac

  #this return prevents from echoing below
  if [[ "${__fgbg}" = "1" ]] ; then return
  fi

  echo -e "${__textcolor:-}${__text:-}${resetall}"

  }

    _colorbackground16() {

  if [[ "$#" -eq 0  || "$#" -gt 2 ]]; then return
  fi

  __backgroundcolor=${1:-} #don't make this local. it is used elsewhere
  local __text=${2:-}

  case ${__backgroundcolor} in

     "black")     __backgroundcolor=${black_bg}
                  ;;
     "red")       __backgroundcolor=${red_bg}
                  ;;
     "green")     __backgroundcolor=${green_bg}
                  ;;
     "yellow")    __backgroundcolor=${yellow_bg}
                  ;;
     "blue")      __backgroundcolor=${blue_bg}
                  ;;
     "magenta")   __backgroundcolor=${magenta_bg}
                  ;;
     "cyan")      __backgroundcolor=${cyan_bg}
                  ;;
     "lgrey")     __backgroundcolor=${lightgrey_bg}
                  ;;
     "dgrey")     __backgroundcolor=${darkgrey_bg}
                  ;;
     "lred")      __backgroundcolor=${lightred_bg}
                  ;;
     "lgreen")    __backgroundcolor=${lightgreen_bg}
                  ;;
     "lyellow")   __backgroundcolor=${lightyellow_bg}
                  ;;
     "lblue")     __backgroundcolor=${lightblue_bg}
                  ;;
     "lmagenta")  __backgroundcolor=${lightmagenta_bg}
                  ;;
     "lcyan")     __backgroundcolor=${lightcyan_bg}
                  ;;
     "white")     __backgroundcolor=${white_bg}
                  ;;
            *)    echo -ne "${red_bg}Unknown background color:${resetall}"
                  ;;
  esac

  #this return prevents from echoing below
  if [[ "${__fgbg}" = "1" ]] ; then return
  fi

  echo -e "${__backgroundcolor:-}${__text:-}${resetall}"

  }

  _colorfgbg256() {

  if [[ "$#" -eq 0 || "$#" -gt 3 ]]; then return
  fi

  __fgbg="1"  #set the flag to block function echos
  _colortext16 ${1:-}       #set the foreground color
  _colorbackground16 ${2:-} #set the background color
  __fgbg="0"  #reset the flag to allow function echos

  local __text=${3:-}
  echo -e "${__textcolor:-}${__backgroundcolor:-}${__text:-}${resetall}"

  }

  _howmanycolors() {

  echo "Your terminal is \"${TERM}\" and, it supports $(tput colors) colors."

  }

  _tputcolors()  {

  if tput setaf 1 &> /dev/null; then
      tput sgr0
      readonly tbell=$(tput bel)
      readonly tbold=$(tput bold)
      readonly tresetall=$(tput sgr0)

      if [ "$(tput colors)" -ge "256" ] 2>/dev/null; then

         # Add more foreground and background colors
         # that you like to use

         # use _colortable function more colors

         #foreground colors
         readonly tblue=$(tput setaf 33)
         readonly tgreen=$(tput setaf 46)
         readonly tlightblue=$(tput setaf 105)
         readonly tpurple=$(tput setaf 129)
         readonly tgold=$(tput setaf 142)
         readonly torange=$(tput setaf 166)
         readonly tred=$(tput setaf 196)
         readonly tyellow=$(tput setaf 226)
         readonly twhite=$(tput setaf 255)

         # background colors
         readonly tblue_bg=$(tput setab 21)
         readonly tgreen_bg=$(tput setab 40)
         readonly tred_bg=$(tput setab 160)
         readonly tmagenta_bg=$(tput setab 165)
         readonly twhite_bg=$(tput setab 255)

         #combinations, use directly
         readonly tblue_bold=${tbold}${tblue}
         readonly tgreen_bold=${tbold}${tgreen}
         readonly tred_bold=${tbold}${tred}
         readonly twhite_bold=${tbold}${twhite}

      fi
   fi
  }

  _colortable () {

  # taken from https://misc.flogisoft.com/bash/tip_colors_and_formatting#colors2

  for fgbg in 38 48 ; do # Foreground / Background
      for color in {0..255} ; do # Colors
          # Display the color
          printf "${esc1}${fgbg};5;%sm  %3s  ${esc1}0m" $color $color
          # Display 6 colors per line
          if [ $((($color + 1) % 6)) == 4 ] ; then
             echo # New line
          fi
      done
      echo # New line
  done
}

  #*************************
  #*    Set tput colors    *
  #*************************

  #when the tput command exists, set the tput colors
  if  [ -x "$(command -v tput)" ]; then
     _tputcolors
  fi

} #end bracket required to run script. Do Not Remove
