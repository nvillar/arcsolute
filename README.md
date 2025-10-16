# arcsolute

This iii lua script turns a monome arc into a simple MIDI controller with four smooth, high-resolution, absolute-position knobs with LED feedback.

It requires a 2025 monome arc, capable of running iii scripts.

## Installation
See [iii docs](https://monome.org/docs/iii/) for instructions on how to upload scripts to the arc.

## Using
- knob turning: sends a MIDI CC value (0-127) on the assigned CC number and MIDI channel
- long-pressing button: toggle between play and config modes
- short-pressing button: play mode resets values; config mode cycles cc/channel/brightness options

## Configuration mode
The configuration mode is based on the [cycles script](https://monome.org/docs/iii/library/cycles/) by tehn.

### Setting MIDI CC Number
The current CC number for each knob, ranging from 0 to 127, is shown as three groups of LEDs that represent the ones (10 LEDs), tens (10 LEDs), and hundred (1 LED) components of the value. When you position the arc so that the long side with the button is closest to you, the ones digit is located at the bottom of the arc.

Here are some example CC number LED values, where │ = partially lit and █ = fully lit:  

```
cc       ones        tens         hundred
	
	     0           0           0
0        ││││││││││  ││││││││││  │  
  
         1           0           0
1        │█││││││││  ││││││││││  │  

         2           0           0
2        ││█│││││││  ││││││││││  │  
  
         0           1           0 
10       ││││││││││  │█││││││││  │  

         2           1           0
12       ││█│││││││  │█││││││││  │ 

	     3           2           1  		
123      │││█││││││  ││█│││││││  █  
```

### Setting the MIDI Channel Number
The current channel number for each knob, ranging from 1 to 16. When you position the arc so that the long side with the button is closest to you, 1 is at the bottom, and 16 at the top.

Here are some example channel number LED values, where │ = partially lit and █ = fully lit:

```
channel  
  
1        █│││││││││││││││
  
8        │││││││█││││││││
  
16       │││││││││││││││█
```
  

### Setting the Brightness
The shared LED brightness can be adjusted between low and high levels while in configuration mode. The left pair of knobs sets the low brightness (values 1–10) and the right pair sets the high brightness (values 2–15). The high level must always stay at least one step above the low level, so turn the right knobs up if you need more headroom.

