# Camera

IOS Camera test
---------------
Object: test camera api knowledge.
The idea is to create a simple app the uses the camera api to allow the user to create a short video clip using either the front or rear camera and the apply some transformations to the resulting video.

![alt tag](https://github.com/jam891/Camera/blob/master/Camera/Assets.xcassets/screen.imageset/screen.png)

The view is composed of the following:

Video Preview:
-------------
This should display a preview of what the camera can see - Cropped at a 1:1 ratio
So although the source video is either portrait or landscape the preview displays the centre Square of the source

Camera select:
-------------
A simple toggle Bar button item allowing the user to switch between the two phone cameras

Blurred background:
------------------
The background will display a blurred preview of the same source video being displayed in the preview area, although it will use the original source ratio and will extend to fill the entire background.

Action area:
-----------
Starts off as a simple record button. when the user taps the recording starts and the duration is displayed. when the user re-taps the recording stops and processing begins.

Once the user completes the recording the video will be post-processed to create a final video from the cropped area displayed in the preview (centre 1:1 ratio crop) and will be downsized to 300x300 pixels and save tho the gallery.
