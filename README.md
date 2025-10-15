# arcsolute

This iii lua script turns a monome arc into a simple MIDI controller with four smooth, high-resolution, absolute-position knobs with LED feedback.

It requires a 2025 monome arc, capable of running iii scripts.

## Installation
See [iii docs](https://monome.org/docs/iii/) for instructions on how to upload scripts to the arc.

## Using
- knob turning: sends a MIDI CC value (0-127) on the assigned CC number and MIDI channel
- long-pressing button: toggle between play and config modes
- short-pressing button: play mode resets values; config mode toggles cc/channel option

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
  
