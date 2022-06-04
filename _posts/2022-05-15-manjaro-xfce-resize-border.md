---
title: Enlarge window border resize area (XFCE)
categories: Manjaro
tags: Xfce configure
shortname: xfce-grab-border
excerpt: Customize window border width for better grab experience and color highlight.
---

# {{ page.title }}
{: .no_toc }

| Matcha-sea               |  Matcha-sea-grab |
:-------------------------:|:-------------------------
![Original Matcha-sea theme](/images/posts/2022-05-15-manjaro-xfce-resize-border/matcha-sea.png) | ![Customized Matcha-sea-grad theme](/images/posts/2022-05-15-manjaro-xfce-resize-border/matcha-sea-grab.png)

# Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

{% include disclaimer.html %}

# Introduction

Often asked in the [Manjaro forum] and eg. answered in [this thread][1]. 

The simple workaround is to use some keyboard shortcuts:
* [alt]+[f8] and just drag the mouse.
* [alt]+[rmb]+[drag]. changes either width or height depending on drag direction

There's a third answer in the post telling
* gtk.css css to increase border and/or gripper (may be affected by CSD (client side decoration)).

So I wonder how to adjust that to get a better handling of the standard mouse operations grab and drag borders.

I checked provided themes of my Manjaro installation and I could not find one (that pleases) and has a bigger graspable  area to just use the mouse.

So I needed to adjust it myself manually.

It might help you to customize your theme on Manjaro or any other Xfce based windowing system.
I won't get in details how themes work in general or dive deep into the related stuff. Just a brief setup to get some fancy border.

| Here's how the default _Matcha-sea_ theme looks like. Nearly no window frame to grab. An the difference between active and inactive is not very expressive. Just a slightly brighter title name and a red close button. | ![Matcha-sea default theme](/images/posts/2022-05-15-manjaro-xfce-resize-border/0-matcha-sea-theme.png)

# Preparation

I could not find something like an add-on theme, where one could just customize some aspects. So I took a copy of my standard theme as a base.

My customization will be based on _Matcha-sea_ so I place a copy in my user themes folder.

```bash
$ mkdir -p ~/.themes/Matcha-sea-grab
$ cp -r /usr/share/themes/Matcha-sea/xfwm4 ~/.themes/Matcha-sea-grab
```
Now one can select the theme from the _Window Manager_ application and it will look exactly as _Matcha-sea_.

## Content description

* You will find a `themerc` with settings and customized colors there.

* the others are png images defining the areas of the window decoration depending on the status (active/inactive...).

  So for example `left-active.png` defines the left border and `bottom-left-active.png` the lower left corner of the window decoration when the window is activated.

# Customization

To customize these you have to change or exchange these with the content you like to have. You might draw a new _PNG_ image for the border, but I found it easier to replace the _PNG_s with simple _XPM_ bitmaps

`left-active.png` file is a one pixel width image resulting in a one pixel border ![x](/images/posts/2022-05-15-manjaro-xfce-resize-border/left-active.png) which is really hard to grab.

Just create an _XPM_ file with the desired bitmap and place it in the folder. If you do not delete the _PNG_ it will be added as an overlay after rendering the _XPM_.

## XPM in brief

* Declaration "static char * left_active_xpm[]"

  defines character array for the bitmap. At least for _Xfce_ the name is not important. Only the filename is used. But it might be a good idea to keep them consistent.

* Layout : "x y c 1" (example "3 4 2 1")
  * a bitmap of _x_*_y_ pixels (3*4)
  * using _c_ number of colors (2)

* Colors: "CHAR c #RGB [s name]" (example: x c #000000 s active_color_1")

  We have stated we will use two colors in the Layout we will need to two rows here
  * color all letters _CHAR_ in the _Bitmap_ definition (x)
  * use named color _name_ if this is defined by underlying _GTK_ or in the themerc file (active_color_1)
  * if not used or undefined use RGB color define with _c_ (#000000)

* Bitmap "x.x."
  we said 3*4, so we need 3 lines of 4 characters
  * every _x_ will be colored in one color and every . in another one

* Example
  ```c++
  /* XPM */
  static char * left_active_xpm[] = {
    "5 5 2 1",
    "x c #000000 s active_color_1",
    ". c #FFFFFF s active_color_2",
    "xxxxx",
    "x...x",
    "x.x.x",
    "x...x",
    "xxxxx",
  };
```

# Customizing the borders

## Change border width

I found the supplied Default/xfwm4 theme provides _XPM_ border definitions wth 5 pixel in width. Just take them.

* Copy these from `/usr/share/themes/Default/xfwm4` to `~/.themes/Matcha-sea-grad/xfwm4`.
* Delete the corresponding _PNG_ images (*.png)

I start with the active border images, so I need 

* left-active
* right-active
* bottom-active
* bottom-left-active
* bottom-right active
* top-left-active
* top-right-active

| And the result is: a thick light gray border and at a closer look you will see it's fringed in the top left and right corner. | ![use borders from theme Default](/images/posts/2022-05-15-manjaro-xfce-resize-border/1-default-border.png)

## Fix up colors

Checking the bitmap I see the used color is `"@      c #C0C0FF s inactive_color_2"` and so I changed it to `"@      c #C0C0FF s active_color_1"`.

| Now the borders shows up in the base _Gtk_ defined color but you still see it fringed at the top corners. | ![Border color fix](/images/posts/2022-05-15-manjaro-xfce-resize-border/2-color-fix.png)

## Fix up width

Looking at the bitmap definition I found the border is 8 pixels instead of 5. 

```c
"8 29 2 1",
"       c None",
".      c #C0C0FF s active_color_1",
"    ....",
"  ......",
" .......",
" .......",
"........",
"........",
"........",
```

Change it to 5 pixels using no color for the remaining three.

```c
"8 29 2 1",
"       c None",
".      c #C0C0FF s active_color_1",
"    .   ",
"  ...   ",
" ....   ",
" ....   ",
".....   ",
".....   ",
".....   ",
```

| Now the border shows up with the desired with. We still have a fringe. | ![Border width fix](/images/posts/2022-05-15-manjaro-xfce-resize-border/3-width-fix.png)

## Fix up title bar fringe

Using no color is a bad choice because of transparencies and the overlay icon bitmaps. We need to use the color of the rest of the title bar. Unfortunately I found no defined color that is the same. I took a screenshot and a color picker to get the value. `#1B2224`. 

Now define the color in our `themerc` file. Add a line at the end with the definition:

  `matcha-sea_active_bg=#1B2224`

Now add this as a third color and here we go:

```c
"8 29 3 1",
"       c None",
".      c #C0C0FF s active_color_1",
"#      c #1B2224 s matcha-sea_active_bg",
"    .###",
"  ...###",
" ....###",
" ....###",
".....###",
".....###",
".....###",
```

| All fine now all borders are as intended. | ![Border fringe fix](/images/posts/2022-05-15-manjaro-xfce-resize-border/4-fringe-fix.png)

## Adapt inactive border layout

Similar adjustments have to be done for the inactive border. Start with the copy of the border files, check the result and adjust size and colors. It's a little easier since we use the same color as the title bar. Mostly it is changing all colors to `"#      c #1B2224 s matcha-sea_active_bg"`

The final result shows imho nice graspable highlighted borders.

![Final border theme](/images/posts/2022-05-15-manjaro-xfce-resize-border/5-borders-finished.png)


# Customize the title bar

The title bar is harder to style.  There are icons inside with overlay the border. Unfortunately the icons are not defined with transparency but special colored for _Matcha-sea_. The result when just changing the border images appears little awkward.

Also this might be affected by the underlying _Gtk_ - It's more than just a simple border definition. 

The title bar is made of 5 bitmap definitions named `title-N-state.png`. We will replace the _PNG_ files with our own _XPM_s defining fully colored in our nice green as we did with the borders.

As you can imagine the active titles text color defined as `active_text_color=#afb8c5` in our `themerc` file, which is a light gray, will become unreadable, so we change it to black `active_text_color=#000000`

All 5 _PNG_s are 5x28 pixels. The first line has color #313839 and the latter ones #1B2224. We simple want all green and the title bar in fact seems to be 29 pixels in height (checked from the top-left-active.xpm, so we will add one pixel. We now have no small separator line between title and menu.

```c
/* XPM */
static char * title_5_active_xpm[] = {
"5 29 1 1",
"1      c #C0C0FF s active_color_1",
/* 29 lines of these */
"....."
};
```


| Quite nice, but we see a border around the Window menu icon on the left and large dark gray areas on the right icons. | ![colored title bar](/images/posts/2022-05-15-manjaro-xfce-resize-border/6-top-active-title-color.png)

## Fix window menu icon color

The left window menu icon has _PNG_ overlays defined for _active_ and _pressed_ state in the dark gray color. I tried with transparency and deleting the image, but then no icon is shown. Looks like there's a xor definition merging this bitmap and the icon image.

| Lets change the two bitmaps `menu-active.png` and `menu-pressed.png` to have a solid fill with _active_color_1_ defined by our theme (#2EB398). We keep the original size 26x16. | ![colored title bar meu icon](/images/posts/2022-05-15-manjaro-xfce-resize-border/7-top-title-menu-colored.png)

## Fix right icons background

All the icons on the right are _PNG_ files with a solid background and smooth edges on the icon. Just switching the background color to be transparent will enable a green background but the edges of the icons are fringed.

Instead of trying to edit the _PNG_s, I found it easier to create new ones.

There are some _SVG_ sources in the _Matcha-sea_ folders and I took some of these, adjusted and changed colors to better fit the green title bar. Saved that as _PNG_ with transparent background and image size 28x28.

Have a look at the screenshot below. On the right side you see some of the original icons with background color and on the left my styled icons including states _prelight_ and _pressed_. I also created new images for the _inactive_ windows.

It should be possible to use these with other title bar colors due to the transparaency and no smothed edges of the icons.

![colored title bar right icons](/images/posts/2022-05-15-manjaro-xfce-resize-border/8-top-title-icons-colored.png)

# Ramp Up

Putting that altogether I got my customized highlighted Window frame.

![final result](/images/posts/2022-05-15-manjaro-xfce-resize-border/9-final-result-small.png)

If you like the style and color, you may just replace the content of your `~/.themes/Matcha-sea-grab/
xfwm4` folder with the content of [Theme file Archive].

# Special Applications

Some applications create their own style or use the Gtk ones but some offer the possibility to use the window manager style.

## Chromium

You can force _Chromium_ to use the system style by right clicking on the title bar and check 'use system title bar and borders`.

![Chromium switch theme](/images/posts/2022-05-15-manjaro-xfce-resize-border/chromium-titlebar.png)

# System configuration

* Manjaro Quonos 21.2.6 (XFCE)

# Tools used

* Text editor for editing the XPM files (vscode / mousepad)
* Inkscape for _SVG_ editing and conversion to _PNG_

# Resources

* [Manjaro forum]
  * [https://forum.manjaro.org/t/having-a-hard-time-resizing-windows/86547](https://forum.manjaro.org/t/having-a-hard-time-resizing-windows/86547)
* [MX Linux Wiki]
  * [https://mxlinux.org/wiki/xfce/changing-border-size-with-xfce4-window-manager/](https://mxlinux.org/wiki/xfce/changing-border-size-with-xfce4-window-manager/)
* [XFCE Linux Wiki]
  * [https://wiki.xfce.org/howto/xfwm4_theme#list_of_frame_and_button_part_names](https://wiki.xfce.org/howto/xfwm4_theme#list_of_frame_and_button_part_names)
* Download final [Theme file Archive]

[Manjaro forum]: https://forum.manjaro.org
[1]: https://forum.manjaro.org/t/having-a-hard-time-resizing-windows/86547

[MX Linux wiki]: https://mxlinux.org/wiki/
  
[XFCE Linux Wiki]: https://wiki.xfce.org/

[Theme file Archive]: /downloads/Matcha-sea-grab-xfwm4.zip