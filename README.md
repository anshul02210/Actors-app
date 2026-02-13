[comment]: # (You may find the following markdown cheat sheet useful: https://www.markdownguide.org/cheat-sheet/. You may also consider using an online Markdown editor such as StackEdit or makeareadme.) 

## Project title: Actor's Line Learning Tool

### Student name: Anshul Kumar

### Student email: ak1108@student.le.ac.uk

### Project description: 
This project aims to develop an AI-powered mobile application to assist actors in memorising and rehearsing their script lines independently. The application will allow users to upload or input a script, select their character role, and practise dialogue through interactive rehearsal. The system will read other characters’ lines using Text-to-Speech (TTS) technology and listen to the actor’s spoken responses using Speech Recognition. The spoken input will be compared with the original script using text similarity algorithms to provide accuracy feedback. The project focuses on integrating speech technologies, implementing text comparison techniques, and evaluating system performance in terms of accuracy, usability, and response time. The final deliverable will be a functional mobile prototype supported by technical evaluation and analysis.

### List of requirements (objectives): 

[comment]: # (You can add as many additional bullet points as necessary by adding an additional hyphon symbol '-' at the end of each list) 

Essential:
- User registration and login functionality
- Ability to upload or paste script text into the application
- Manual tagging or selection of character roles within the script
- Selection of “My Role” for rehearsal
- Storage of scripts in structured format
- Text-to-Speech integration to read other characters’ lines
- Speech-to-Text integration to convert actor’s spoken lines into text
- Text comparison using basic string similarity (e.g: Levenshtein Distance)
- Display similarity score (correct / partially correct / incorrect)
- Highlight mismatched or missing words
- Core mobile interface including login, script upload, rehearsal screen, and feedback screen

Desirable:
- Different voice options for different characters
- Adjustable speech playback speed
- Multiple practice modes (Assisted Mode and Challenge Mode)
- Progress tracking with stored rehearsal history
- Basic performance statistics (accuracy percentage, number of attempts)
- Importing script files (.txt,pdf,word format)
- Basic timing measurement of actor response delay
- Simple progress visualisation (e.g.: accuracy over time chart)

Optional:
- Advanced NLP-based semantic similarity comparison (meaning-based matching)
- Emotion or tone detection from actor’s speech
- Filler word detection (e.g.: “um”, “uh”)
- Accent adaptation or pronunciation tuning
- Custom machine learning model training for speech recognition
- Advanced performance coaching feedback system
- Fully scalable cloud-based backend infrastructure


## Information about this repository
This repository contains the development of an AI-powered mobile application designed to assist actors in memorising and rehearsing script lines independently. The system allows users to upload scripts, select their role, practise dialogue using Text-to-Speech (TTS), and receive feedback through Speech Recognition and text similarity comparison.

The application is built using Dart and the Flutter framework for cross-platform mobile development (Android and iOS).

The system integrates:

- Text-to-Speech functionality
- Speech-to-Text recognition
- Script management
- Text similarity evaluation
- Performance feedback

The development of this project follows incremental commits once features are functional and integrated.
/actor_line_learning_app
│
├── /lib
│   ├── main.dart
│   ├── /screens
│   │     ├── login_screen.dart
│   │     ├── script_upload_screen.dart
│   │     ├── rehearsal_screen.dart
│   │     └── feedback_screen.dart
│   │
│   ├── /services
│   │     ├── speech_to_text_service.dart
│   │     ├── text_to_speech_service.dart
│   │     ├── script_parser_service.dart
│   │     └── similarity_service.dart
│   │
│   ├── /models
│   │     ├── script_model.dart
│   │     ├── character_model.dart
│   │     └── performance_model.dart
│   │
│   ├── /utils
│   │     ├── constants.dart
│   │     └── helper_functions.dart
│
├── /assets
│
├── /test
│
├── pubspec.yaml
│
└── README.md

