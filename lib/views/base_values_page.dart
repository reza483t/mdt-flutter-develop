import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helloworldtor/entity/initial-values.dart';
import 'package:helloworldtor/ip_text_format.dart';
import 'package:helloworldtor/main.dart';

class BaseValuesPage extends StatefulWidget {
  const BaseValuesPage({super.key});

  @override
  State<BaseValuesPage> createState() => _BaseValuesPageState();
}

class _BaseValuesPageState extends State<BaseValuesPage> {
  final TextEditingController _ipTextController = TextEditingController();
  final TextEditingController _portTextController = TextEditingController();
  final TextEditingController _passwordTextController = TextEditingController();
  bool _passwordCheckBoxValue = false;
  late BuildContext context;
  final FocusNode _portTextFieldFocusNode = FocusNode();
  final FocusNode _passwordRTextFieldFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    this.context = context;
    return Scaffold(
      backgroundColor: const Color(0xff222831),
      appBar: _appBar(),
      body: _body(),
    );
  }

  _passwordCheckBoxEvent(newValue) {
    setState(() {
      _passwordCheckBoxValue = newValue;
    });
  }

  _applyButtonEvent() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => TorControlPage(
              initialValues: InitialValues(
                  _ipTextController.text,
                  int.parse(_portTextController.text),
                  _passwordTextController.text),
            )));
  }

  AppBar _appBar() {
    return AppBar(
      backgroundColor: const Color(0xff393E46),
      title: const Text(
        "Init Values Page",
        style: TextStyle(fontSize: 30, color: Color(0xff00ADB5)),
      ),
    );
  }

  Widget _body() {
    return Container(
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          customTextField(
              "ip",
              _ipTextController,
              "192.168.1.1",
              TextInputType.text,
              [IpTextFormat()],
              TextField.noMaxLength, (value) {
            _portTextFieldFocusNode.requestFocus();
          }),
          const SizedBox(height: 10),
          customTextField(
              "port",
              _portTextController,
              "9051",
              TextInputType.number,
              [FilteringTextInputFormatter.digitsOnly],
              4, (value) {
            if (_passwordCheckBoxValue)_passwordRTextFieldFocusNode.requestFocus();
          }, _portTextFieldFocusNode),
          passwordCheckBox(),
          const SizedBox(height: 10),
          Opacity(
            opacity: _passwordCheckBoxValue ? 1 : 0.5,
            child: customTextField(
                "password",
                _passwordTextController,
                "1234",
                TextInputType.text,
                [],
                8),
          ),
          const SizedBox(height: 35),
          SizedBox(
            width: MediaQuery.of(context).size.width / 2,
            height: 45,
            child: TextButton(
              onPressed: _applyButtonEvent,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xff00ADB5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:const Text(
                'Apply',
                style: TextStyle(
                    fontSize: 16,
                    color: Color(0xffEEEEEE)
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget passwordCheckBox() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: _passwordCheckBoxValue,
          onChanged: _passwordCheckBoxEvent,
          checkColor: const Color(0xff00ADB5),
          activeColor: Colors.transparent,
        ),
        const SizedBox(width: 5),
        const Text(
          "do you have password ?",
          style: TextStyle(fontSize: 20, color: Color(0xffEEEEEE)),
        )
      ],
    );
  }

  Widget customTextField(
      String label,
      TextEditingController textController,
      String hintText,
      TextInputType keyBoardType,
      List<TextInputFormatter> textInputFormatters,
      int maxLength,
      [
        void Function(String)? onSubmitted = null,
        FocusNode? focusNode = null
      ]) {
    return TextField(
      controller: textController,
      decoration: InputDecoration(
          label: Text(
            label,
            style: const TextStyle(
                color: Color(0xff00ADB5),
                fontSize: 17,
                fontWeight: FontWeight.w700),
          ),
          hintText: hintText,
          filled: true,
          fillColor: const Color(0xff393E46),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent),
              borderRadius: BorderRadius.all(Radius.circular(16)))),
      style: const TextStyle(fontSize: 25, color: Color(0xffEEEEEE)),
      keyboardType: keyBoardType,
      inputFormatters: textInputFormatters,
      maxLength: maxLength,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      cursorColor: const Color(0xff00ADB5),
    );
  }
}