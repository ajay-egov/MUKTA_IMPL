import 'package:collection/collection.dart';
import 'package:digit_components/digit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:works_shg_app/blocs/muster_rolls/create_muster.dart';
import 'package:works_shg_app/utils/common_widgets.dart';
import 'package:works_shg_app/utils/localization_constants/i18_key_constants.dart' as i18;
import 'package:works_shg_app/widgets/Back.dart';
import 'package:works_shg_app/widgets/WorkDetailsCard.dart';
import 'package:works_shg_app/widgets/atoms/custom_info_card.dart';
import 'package:works_shg_app/widgets/atoms/empty_image.dart';
import 'package:works_shg_app/widgets/molecules/digit_table.dart' as shg_app;

import '../blocs/attendance/attendance_create_log.dart';
import '../blocs/attendance/attendance_hours_mdms.dart';
import '../blocs/attendance/skills/skills_bloc.dart';
import '../blocs/localization/app_localization.dart';
import '../blocs/localization/localization.dart';
import '../blocs/muster_rolls/get_muster_workflow.dart';
import '../blocs/muster_rolls/muster_inbox_status_bloc.dart';
import '../blocs/muster_rolls/muster_roll_estimate.dart';
import '../blocs/muster_rolls/muster_roll_pdf.dart';
import '../blocs/muster_rolls/search_individual_muster_roll.dart';
import '../models/attendance/attendee_model.dart';
import '../models/mdms/attendance_hours.dart';
import '../models/muster_rolls/estimate_muster_roll_model.dart';
import '../models/muster_rolls/muster_roll_model.dart';
import '../models/muster_rolls/muster_workflow_model.dart';
import '../models/skills/skills.dart';
import '../router/app_router.dart';
import '../utils/common_methods.dart';
import '../utils/constants.dart';
import '../utils/date_formats.dart';
import '../utils/models.dart';
import '../utils/models/track_attendance_payload.dart';
import '../utils/notifiers.dart';
import '../widgets/ButtonLink.dart';
import '../widgets/CircularButton.dart';
import '../widgets/SideBar.dart';
import '../widgets/atoms/app_bar_logo.dart';
import '../widgets/atoms/digit_timeline.dart';
import '../widgets/atoms/table_dropdown.dart';
import '../widgets/drawer_wrapper.dart';
import '../widgets/loaders.dart' as shg_loader;

class SHGInboxPage extends StatefulWidget {
  final String tenantId;
  final String musterRollNo;
  final String sentBackCode;

  const SHGInboxPage(@PathParam('tenantId') this.tenantId,
      @PathParam('musterRollNo') this.musterRollNo,
      @PathParam('sentBackCode') this.sentBackCode,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _SHGInboxPage();
  }
}

class _SHGInboxPage extends State<SHGInboxPage> {
  // AttendanceRegister? _attendanceRegister;
  DateRangePickerController rangePickerController = DateRangePickerController();
  DateRangePickerSelectionMode selectionMode =
      DateRangePickerSelectionMode.single;
  String? registerId;
  String? musterId;
  List<Map<String, dynamic>> projectDetails = [];
  DateRange? selectedDateRange;
  bool showTimeLine = false;
  var dateController = TextEditingController();
  var searchController = TextEditingController();
  List<TrackAttendanceTableData> newList = [];

  List<Map<String, dynamic>> updateAttendeePayload = [];
  List<Map<String, dynamic>> createAttendeePayload = [];
  List<Map<String, dynamic>> skillsPayLoad = [];
  List<TableDataRow> tableData = [];
  bool hasLoaded = true;
  bool updateLoaded = true;
  bool hide = true;
  List<EntryExitModel>? entryExitList;
  List<Skill> skillList = [];
  List<String> skillDropDown = [];
  List<DigitTimelineOptions> timeLineAttributes = [];
  DaysInRange? daysInRange;
  bool inWorkFlow = false;
  List<String> dates = [];

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) => afterViewBuild());
    super.initState();
  }

  afterViewBuild()  {
    context.read<IndividualMusterRollSearchBloc>().add(
      SearchIndividualMusterRollEvent(
          musterRollNumber: widget.musterRollNo,
          tenantId: widget.tenantId.toString()),
    );
    context.read<MusterGetWorkflowBloc>().add(
          GetMusterWorkflowEvent(
              tenantId: widget.tenantId, musterRollNumber: widget.musterRollNo, musterSentBackCode: widget.sentBackCode),
        );
    context.read<AttendanceHoursBloc>().add(
          const AttendanceHoursEvent(),
        );
    context.read<MusterInboxStatusBloc>().add(
      const MusterInboxStatusEvent(),
    );
    context.read<SkillsBloc>().add(
          const SkillsEvent(),
        );
  }


  @override
  void deactivate() {
    context.read<MusterRollEstimateBloc>().add(
      const DisposeEstimateMusterRollEvent(),
    );
    context.read<MusterGetWorkflowBloc>().add(
      const DisposeMusterRollWorkflowEvent(),
    ); // Change the state of the widget when it is no longer visible
    super.deactivate();
  }
  @override
  void dispose() {
    // Clear the data when the widget is disposed
    newList.clear();
    tableData.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width < 760
        ? 150.0
        : (MediaQuery.of(context).size.width / 7.5);
    var t = AppLocalizations.of(context);
    return WillPopScope(
      onWillPop: () async {
        context.router.popUntilRouteWithPath('home') ;
        context.router.push(const ViewMusterRollsRoute());
        return false;
      },
      child: BlocBuilder<LocalizationBloc, LocalizationState>(
          builder: (context, localState) {
          return Scaffold(
              appBar: AppBar(
                titleSpacing: 0,
                title: const AppBarLogo(),
              ),
              drawer: DrawerWrapper(Drawer(
                  child: SideBar(
                module: CommonMethods.getLocaleModules(),
              ))),
              body: BlocBuilder<SkillsBloc, SkillsBlocState>(
                  builder: (context, skillsState) {
                return skillsState.maybeWhen(
                    orElse: () => Container(),
                    loading: () => shg_loader.Loaders.circularLoader(context),
                    error: (String? error) => Notifiers.getToastMessage(
                        context,
                        AppLocalizations.of(context).translate(error.toString()),
                        'ERROR'),
                    loaded: (SkillsList? skillsList) {
                      skillList = skillsList!.wageSeekerSkills
                              ?.where((obj) => obj.active == true)
                              .map((e) => Skill(
                                    code: e.code,
                                  ))
                              .toList() ??
                          [];
                      for (Skill skill in skillList) {
                        skillDropDown.add(skill.code);
                      }
                      return BlocBuilder<AttendanceHoursBloc, AttendanceHoursState>(
                          builder: (context, mdmsState) {
                        return mdmsState.maybeWhen(
                            orElse: () => Container(),
                            loading: () => shg_loader.Loaders.circularLoader(context),
                            loaded: (AttendanceHoursList? attendanceHoursList) {
                              entryExitList = attendanceHoursList!.attendanceHours
                                  ?.where((obj) => obj.active == true)
                                  .map((e) => EntryExitModel(
                                      hours: int.parse(e.value), code: e.code))
                                  .toList();
                              return BlocBuilder<MusterInboxStatusBloc, MusterInboxStatusState>(
                                  builder: (context, searchState) {
                                    return searchState.maybeWhen(orElse: () => Container(),
                                  loading: () => shg_loader.Loaders.circularLoader(context),
                                  loaded: (String? sentBackToCBOCode) => BlocListener<IndividualMusterRollSearchBloc, IndividualMusterRollSearchState>(
                                    listener: (context, state) {
                                      state.maybeWhen(orElse: () => false,
                                      loading: () => shg_loader.Loaders.circularLoader(context),
                                          error : (String? error) => Notifiers.getToastMessage(context, t.translate(error.toString()), 'ERROR'),
                                      loaded: (MusterRollsModel? individualMusterRollModel) {
                                        context.read<MusterRollEstimateBloc>().add(
                                          ViewEstimateMusterRollEvent(
                                            tenantId: widget.tenantId,
                                            registerId: individualMusterRollModel!.musterRoll!.first.registerId.toString(),
                                            startDate: individualMusterRollModel.musterRoll!.first.startDate ?? 0,
                                            endDate: individualMusterRollModel.musterRoll!.first.endDate ?? 0,
                                          ),
                                        );
                                        if(individualMusterRollModel.musterRoll != null && individualMusterRollModel.musterRoll!.isNotEmpty){
                                          projectDetails = individualMusterRollModel.musterRoll
                                              !.map((e) => {
                                            i18.attendanceMgmt.musterRollId:
                                            e.musterRollNumber,
                                            i18.workOrder.workOrderNo:
                                            e.musterAdditionalDetails?.contractId ?? i18.common.noValue,
                                            i18.attendanceMgmt.projectId:
                                            e.musterAdditionalDetails?.projectId ?? i18.common.noValue,
                                            i18.attendanceMgmt.projectName:
                                            e.musterAdditionalDetails?.projectName ?? i18.common.noValue,
                                            i18.attendanceMgmt.projectDesc:
                                            e.musterAdditionalDetails?.projectDesc ??
                                                'NA',
                                            i18.attendanceMgmt.musterRollPeriod:
                                            '${DateFormats.timeStampToDate(e.startDate, format: "dd/MM/yyyy")} - ${DateFormats.timeStampToDate(e.endDate, format: "dd/MM/yyyy")}',
                                            i18.common.status: 'WF_MUSTOR_${e.musterRollStatus}',
                                            Constants.activeInboxStatus : e.musterRollStatus == sentBackToCBOCode
                                                ? 'false'
                                                : 'true'
                                          }).toList();
                                          musterId = individualMusterRollModel
                                              .musterRoll!.first.id;
                                          registerId = individualMusterRollModel
                                              .musterRoll!.first.registerId;
                                          selectedDateRange = DateRange(
                                              '',
                                              individualMusterRollModel
                                                  .musterRoll!.first.startDate ??
                                                  0,
                                              individualMusterRollModel
                                                  .musterRoll!.first.endDate ??
                                                  0);
                                          daysInRange = DateFormats.checkDaysInRange(
                                              DateFormats.dateToTimeStamp(DateFormats.getDateFromTimestamp(selectedDateRange!.startDate)),
                                              DateFormats.dateToTimeStamp(DateFormats.getDateFromTimestamp(selectedDateRange!.endDate)),
                                              individualMusterRollModel
                                                  .musterRoll!.first.startDate!,
                                              individualMusterRollModel
                                                  .musterRoll!.first.endDate!);
                                          dates = DateFormats.getFormattedDatesOfAWeek(selectedDateRange!.startDate, selectedDateRange!.endDate);
                                        }
                                      });
                                    },
                                      child: BlocBuilder<IndividualMusterRollSearchBloc,
                                              IndividualMusterRollSearchState>(
                                          builder: (context, state) {
                                        return state.maybeWhen(
                                            orElse: () => Container(),
                                            loading: () => shg_loader.Loaders.circularLoader(context),
                                            loaded: (MusterRollsModel? individualMusterRollModel) {
                                              return Stack(children: [
                                                Container(
                                                  color:
                                                      const Color.fromRGBO(238, 238, 238, 1),
                                                  padding: const EdgeInsets.only(
                                                      left: 8, right: 8, bottom: 16),
                                                  height: inWorkFlow
                                                      ? MediaQuery.of(context).size.height
                                                      : MediaQuery.of(context).size.height - 180,
                                                  child: CustomScrollView(slivers: [
                                                    SliverList(
                                                        delegate: SliverChildListDelegate([
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Back(
                                                            backLabel:
                                                                AppLocalizations.of(context).translate(i18.common.back),
                                                            callback: () {
                                                              context.router.popUntilRouteWithPath('home') ;
                                                              context.router.push(const ViewMusterRollsRoute());
                                                            },
                                                          ),
                                                          CommonWidgets.downloadButton(AppLocalizations.of(context)
                                                              .translate(i18.common.download), () {
                                                            context.read<MusterRollPDFBloc>().add(PDFEventMusterRoll(
                                                              musterRollNumber: widget.musterRollNo,
                                                              tenantId: widget.tenantId)); })
                                                        ],
                                                      ),
                                                      WorkDetailsCard(
                                                        projectDetails,
                                                        showButtonLink: true,
                                                        musterBackToCBOCode: sentBackToCBOCode,
                                                        linkLabel: showTimeLine ? t.translate(i18.common.hideWorkflowTimeline) : t.translate(i18.common.showWorkflowTimeline),
                                                        onLinkPressed: () {
                                                          setState(() {
                                                            showTimeLine = !showTimeLine;
                                                          });
                                                        },
                                                      ),
                                                      BlocListener<MusterGetWorkflowBloc, MusterGetWorkflowState>(
                                                      listener: (context, workflowState) {
                                                        workflowState.maybeWhen(orElse: () => false,
                                                        loading: () => shg_loader.Loaders.circularLoader(context),
                                                        loaded: (MusterWorkFlowModel? musterWorkFlowModel, bool isInWorkFlow) {
                                                          if(musterWorkFlowModel?.processInstances != null && musterWorkFlowModel!.processInstances!.isNotEmpty){
                                                            timeLineAttributes = musterWorkFlowModel.processInstances!.mapIndexed((i, e) =>
                                                                DigitTimelineOptions(
                                                                  title: t.translate('WF_MUSTOR_${e.workflowState?.state}'),
                                                                  subTitle: DateFormats.getTimeLineDate(e.auditDetails?.lastModifiedTime ?? 0),
                                                                  isCurrentState: i == 0,
                                                                  comments: e.comment,
                                                                  assignee: e.assignes?.first.name ,
                                                                  mobileNumber: e.assignes != null ? '+91-${e.assignes?.first.mobileNumber}' : null

                                                            )).toList();
                                                        }
                                                        });
                                                       }, child: Visibility(
                                                        visible: showTimeLine,
                                                         child: BlocBuilder<MusterGetWorkflowBloc, MusterGetWorkflowState>(builder: (context, workflowState) {
                                                           return workflowState.maybeWhen(orElse: () => Container(),
                                                           loading: () => shg_loader.Loaders.circularLoader(context),
                                                           loaded: (MusterWorkFlowModel? musterWorkFlowModel, bool isInWorkFlow) {
                                                             return DigitCard(padding: const EdgeInsets.all(8.0),child: Column(
                                                               crossAxisAlignment: CrossAxisAlignment.start,
                                                               mainAxisAlignment: MainAxisAlignment.start,
                                                               children: [
                                                                 Padding(
                                                                   padding: const EdgeInsets.only(left: 4.0, bottom: 16.0, top: 8.0),
                                                                   child: Text(
                                                                     t.translate(i18.common.workflowTimeline) ?? '',
                                                                     style: DigitTheme.instance.mobileTheme.textTheme.headlineLarge
                                                                         ?.apply(color: const DigitColors().black),
                                                                     textAlign: TextAlign.left,
                                                                   ),
                                                                 ),
                                                                 DigitTimeline(timelineOptions: timeLineAttributes,),
                                                               ],
                                                             ));
                                                           });
                                                      },),
                                                       )
                                                      )
                                                    ])),
                                                    SliverToBoxAdapter(
                                                        child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment.center,
                                                            children: [
                                                          const SizedBox(
                                                            height: 20,
                                                          ),
                                                              BlocBuilder<MusterGetWorkflowBloc, MusterGetWorkflowState>(builder: (context, workflowState) {
                                                                return workflowState.maybeWhen(
                                                                  orElse: () => Container(),
                                                                  loading: () => shg_loader.Loaders.circularLoader(context),
                                                                    loaded: (MusterWorkFlowModel? musterWorkFlowModel, bool isInWorkFlow) => musterWorkFlowModel?.processInstances?.first.workflowState?.state == widget.sentBackCode ? CustomInfoCard(title: AppLocalizations.of(context)
                                                                      .translate(i18.common.info), description: AppLocalizations.of(context)
                                                                      .translate(i18.attendanceMgmt.toMarkAttendance),
                                                                    child: Column(
                                                                      children: entryExitList!.length > 2  ? [
                                                                        Row(children:  [
                                                                          CircularButton(icon: Icons.circle_rounded,
                                                                            size: 15,
                                                                            color: const Color.fromRGBO(0, 100, 0, 1),
                                                                            index: 1,
                                                                            isNotGreyed: false,
                                                                            onTap: () {},),
                                                                          Padding(
                                                                            padding: const EdgeInsets.only(left: 4.0),
                                                                            child: Text('${AppLocalizations.of(context).translate(i18.attendanceMgmt.singleClick)} ${AppLocalizations.of(context).translate(i18.attendanceMgmt.fullDay)}'),
                                                                          )
                                                                        ],),
                                                                        const SizedBox(height: 4,),
                                                                        Row(children: [
                                                                          CircularButton(icon: Icons.circle_rounded,
                                                                            size: 15,
                                                                            color: const Color.fromRGBO(0, 100, 0, 1),
                                                                            index: 0.5,
                                                                            isNotGreyed: false,
                                                                            onTap: () {},),
                                                                          Padding(
                                                                            padding: const EdgeInsets.only(left: 4.0),
                                                                            child: Text('${AppLocalizations.of(context).translate(i18.attendanceMgmt.doubleClick)} ${AppLocalizations.of(context).translate(i18.attendanceMgmt.halfDay)}'),
                                                                          )
                                                                        ],),
                                                                        const SizedBox(height: 4,),
                                                                        Row(children:  [
                                                                          CircularButton(icon: Icons.circle_rounded,
                                                                            size: 15,
                                                                            color: const Color.fromRGBO(0, 100, 0, 1),
                                                                            index: 0,
                                                                            isNotGreyed: false,
                                                                            onTap: () {},),
                                                                          Padding(
                                                                            padding: const EdgeInsets.only(left: 4.0),
                                                                            child: Text('${AppLocalizations.of(context).translate(i18.attendanceMgmt.tripleClick)} ${AppLocalizations.of(context).translate(i18.attendanceMgmt.absent)}'),
                                                                          )
                                                                        ],)
                                                                      ] : [
                                                                        Row(
                                                                          children:  [
                                                                            CircularButton(icon: Icons.circle_rounded,
                                                                              size: 15,
                                                                              color: const Color.fromRGBO(0, 100, 0, 1),
                                                                              index: 1,
                                                                              isNotGreyed: false,
                                                                              onTap: () {},),
                                                                            Padding(
                                                                              padding: const EdgeInsets.only(left: 4.0),
                                                                              child: Text('${AppLocalizations.of(context).translate(i18.attendanceMgmt.singleClick)} ${AppLocalizations.of(context).translate(i18.attendanceMgmt.fullDay)}'),
                                                                            )
                                                                          ],),
                                                                        const SizedBox(height: 4,),
                                                                        Row(children:  [
                                                                          CircularButton(icon: Icons.circle_rounded,
                                                                            size: 15,
                                                                            color: const Color.fromRGBO(0, 100, 0, 1),
                                                                            index: 0,
                                                                            isNotGreyed: false,
                                                                            onTap: () {},),
                                                                          Padding(
                                                                            padding: const EdgeInsets.only(left: 4.0),
                                                                            child: Text('${AppLocalizations.of(context).translate(i18.attendanceMgmt.doubleClick)} ${AppLocalizations.of(context).translate(i18.attendanceMgmt.absent)}'),
                                                                          )
                                                                        ],)
                                                                      ],
                                                                    ),) : const SizedBox.shrink());
                                                                }
                                                              ),
                                                          Container(
                                                              margin:
                                                                  const EdgeInsets.all(8.0),
                                                              child: TextFormField(
                                                                controller: searchController,
                                                                autofocus: false,
                                                                decoration: InputDecoration(
                                                                  hintText: AppLocalizations
                                                                          .of(context)
                                                                      .translate(i18.common
                                                                          .searchByName),
                                                                  border:
                                                                      const OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.zero,
                                                                  ),
                                                                  filled: true,
                                                                  fillColor: Colors.white,
                                                                  prefixIconConstraints:
                                                                      const BoxConstraints(
                                                                          minWidth: 0,
                                                                          minHeight: 0),
                                                                  prefixStyle: TextStyle(
                                                                      fontSize: 16,
                                                                      fontWeight:
                                                                          FontWeight.w400,
                                                                      color: Theme.of(context)
                                                                          .primaryColorDark),
                                                                  prefixIcon: const Padding(
                                                                      padding:
                                                                          EdgeInsets.all(8.0),
                                                                      child: Icon(Icons
                                                                          .search_sharp)),
                                                                ),
                                                                onChanged: (val) =>
                                                                    onTextSearch(),
                                                              )),
                                                          const SizedBox(
                                                            height: 20,
                                                          ),
                                                          individualMusterRollModel
                                                                      ?.musterRoll!
                                                                      .first
                                                                      .individualEntries !=
                                                                  null
                                                              ? BlocBuilder<
                                                                      MusterRollEstimateBloc,
                                                                      MusterRollEstimateState>(
                                                                  builder:
                                                                      (context, musterState) {
                                                                  return musterState
                                                                      .maybeWhen(
                                                                          orElse: () =>
                                                                              Container(),
                                                                          loading: () => shg_loader.Loaders
                                                                              .circularLoader(
                                                                                  context),
                                                                      error : (String? error) => Notifiers.getToastMessage(context, t.translate(error.toString()), 'ERROR'),
                                                                          loaded: (EstimateMusterRollsModel?
                                                                              viewMusterRollsModel) {
                                                                            List<AttendeesTrackList>
                                                                                attendeeList =
                                                                                [];

                                                                            if (viewMusterRollsModel!
                                                                                .musterRoll!
                                                                                .first
                                                                                .individualEntries!
                                                                                .isNotEmpty) {
                                                                              attendeeList = viewMusterRollsModel
                                                                                  .musterRoll!
                                                                                  .first
                                                                                  .individualEntries!.where((est) => est.attendanceEntries != null)
                                                                                  .map((e) => AttendeesTrackList(
                                                                                      name: e.musterIndividualAdditionalDetails?.userName ??
                                                                                          '',
                                                                                      aadhaar: e.musterIndividualAdditionalDetails?.aadharNumber ??
                                                                                          '',
                                                                                      individualId: e
                                                                                          .individualId,
                                                                                      skillCodeList: e.musterIndividualAdditionalDetails?.skillCode ?? [],
                                                                                      individualGaurdianName: e.musterIndividualAdditionalDetails?.fatherName ??
                                                                                            e.musterIndividualAdditionalDetails?.fatherName ?? '',
                                                                                      id: e.id != null ? e.id : individualMusterRollModel!.musterRoll!.first.individualEntries!.any((i) => i.individualId == e.individualId) ? individualMusterRollModel?.musterRoll!.first.individualEntries?.firstWhere((s) => s.individualId == e.individualId).id ?? '' : '',
                                                                                      skill: individualMusterRollModel!.musterRoll!.first.individualEntries!.any((i) => i.individualId == e.individualId)  ? individualMusterRollModel?.musterRoll!.first.individualEntries?.firstWhere((s) => s.individualId == e.individualId).musterIndividualAdditionalDetails?.skillCode ??
                                                                                          '' : '',
                                                                                      monEntryId: e.attendanceEntries != null ? e
                                                                                          .attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Mon')
                                                                                          .attendanceEntriesAdditionalDetails
                                                                                          ?.entryAttendanceLogId : null,
                                                                                      monExitId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Mon').attendanceEntriesAdditionalDetails?.exitAttendanceLogId : null,
                                                                                      monIndex: e.attendanceEntries != null ? e.attendanceEntries!.lastWhere((att) => DateFormats.getDay(att.time!) == 'Mon').attendance ?? -1 : -1,
                                                                                      tueEntryId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Tue').attendanceEntriesAdditionalDetails?.entryAttendanceLogId : null,
                                                                                      tueExitId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Tue').attendanceEntriesAdditionalDetails?.exitAttendanceLogId : null,
                                                                                      tueIndex: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Tue').attendance ?? -1 : -1,
                                                                                      wedEntryId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Wed').attendanceEntriesAdditionalDetails?.entryAttendanceLogId : null,
                                                                                      wedExitId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Wed').attendanceEntriesAdditionalDetails?.exitAttendanceLogId : null,
                                                                                      wedIndex: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Wed').attendance ?? -1 : -1,
                                                                                      thuEntryId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Thu').attendanceEntriesAdditionalDetails?.entryAttendanceLogId : null,
                                                                                      thuExitId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Thu').attendanceEntriesAdditionalDetails?.exitAttendanceLogId : null,
                                                                                      thursIndex: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Thu').attendance ?? -1 : -1,
                                                                                      friEntryId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Fri').attendanceEntriesAdditionalDetails?.entryAttendanceLogId : null,
                                                                                      friExitId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Fri').attendanceEntriesAdditionalDetails?.exitAttendanceLogId : null,
                                                                                      friIndex: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Fri').attendance ?? -1 : -1,
                                                                                      satEntryId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Sat').attendanceEntriesAdditionalDetails?.entryAttendanceLogId : null,
                                                                                      satExitId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Sat').attendanceEntriesAdditionalDetails?.exitAttendanceLogId : null,
                                                                                      satIndex: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Sat').attendance ?? -1 : -1,
                                                                                      sunEntryId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Sun').attendanceEntriesAdditionalDetails?.entryAttendanceLogId : null,
                                                                                      sunExitId: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Sun').attendanceEntriesAdditionalDetails?.exitAttendanceLogId : null,
                                                                                      sunIndex: e.attendanceEntries != null ? e.attendanceEntries?.lastWhere((att) => DateFormats.getDay(att.time!) == 'Sun').attendance ?? -1 : -1,
                                                                                      auditDetails: e.attendanceEntries != null ? e.attendanceEntries?.first.auditDetails : null))
                                                                                  .toList();

                                                                              if (newList.isEmpty) {
                                                                                for (var i = 0; i < attendeeList.length; i++) {
                                                                                  var item1 = attendeeList[i];
                                                                                  TrackAttendanceTableData data = TrackAttendanceTableData();
                                                                                  data.name = item1.name;
                                                                                  data.individualGaurdianName = item1.individualGaurdianName ?? '';
                                                                                  data.aadhaar = item1.aadhaar;
                                                                                  data.individualId = item1.individualId ?? '';
                                                                                  data.id = item1.id ?? '';
                                                                                  data.skill = item1.skill;
                                                                                  data.skillCodeList = item1.skillCodeList ?? [];
                                                                                  data.monIndex = item1.monIndex;
                                                                                  data.monEntryId = item1.monEntryId;
                                                                                  data.monExitId = item1.monExitId;
                                                                                  data.tueIndex = item1.tueIndex;
                                                                                  data.tueEntryId = item1.tueEntryId;
                                                                                  data.tueExitId = item1.tueExitId;
                                                                                  data.wedIndex = item1.wedIndex;
                                                                                  data.wedEntryId = item1.wedEntryId;
                                                                                  data.wedExitId = item1.wedExitId;
                                                                                  data.thuIndex = item1.thursIndex;
                                                                                  data.thuEntryId = item1.thuEntryId;
                                                                                  data.thuExitId = item1.thuExitId;
                                                                                  data.friIndex = item1.friIndex;
                                                                                  data.friEntryId = item1.friEntryId;
                                                                                  data.friExitId = item1.friExitId;
                                                                                  data.satIndex = item1.satIndex;
                                                                                  data.satEntryId = item1.satEntryId;
                                                                                  data.satExitId = item1.satExitId;
                                                                                  data.sunIndex = item1.sunIndex;
                                                                                  data.sunEntryId = item1.sunEntryId;
                                                                                  data.sunExitId = item1.sunExitId;
                                                                                  data.auditDetails = item1.auditDetails;
                                                                                  newList.add(data);
                                                                                }
                                                                              }
                                                                            } else {
                                                                              if (newList.isEmpty) {
                                                                                for (var i = 0; i < attendeeList.length; i++) {
                                                                                  var item1 = attendeeList[i];
                                                                                  TrackAttendanceTableData data = TrackAttendanceTableData();
                                                                                  data.name = item1.name;
                                                                                  data.aadhaar = item1.aadhaar;
                                                                                  data.individualId = item1.individualId ?? '';
                                                                                  data.individualGaurdianName = item1.individualGaurdianName ?? '';
                                                                                  data.id = item1.id ?? '';
                                                                                  data.skill = item1.skill;
                                                                                  data.skillCodeList = item1.skillCodeList;
                                                                                  data.monIndex = item1.monIndex;
                                                                                  data.tueIndex = item1.tueIndex;
                                                                                  data.wedIndex = item1.wedIndex;
                                                                                  data.thuIndex = item1.thursIndex;
                                                                                  data.friIndex = item1.friIndex;
                                                                                  data.satIndex = item1.satIndex;
                                                                                  data.sunIndex = item1.sunIndex;
                                                                                  data.auditDetails = item1.auditDetails;
                                                                                  newList.add(data);
                                                                                }
                                                                              }
                                                                            }
                                                                            tableData =
                                                                                getAttendanceData(
                                                                                    newList);

                                                                            return Column(
                                                                                crossAxisAlignment:
                                                                                    CrossAxisAlignment
                                                                                        .start,
                                                                                children: [
                                                                                  Padding(
                                                                                    padding:
                                                                                        const EdgeInsets.all(
                                                                                            8.0),
                                                                                    child: shg_app
                                                                                        .DigitTable(
                                                                                      headerList:
                                                                                          headerList,
                                                                                      tableData:
                                                                                          tableData,
                                                                                      leftColumnWidth:
                                                                                          width,
                                                                                      rightColumnWidth:
                                                                                          width *
                                                                                              10,
                                                                                      height: 58 +
                                                                                          (52.0 *
                                                                                              (tableData.length + 0.2)),
                                                                                      scrollPhysics:
                                                                                          const NeverScrollableScrollPhysics(),
                                                                                    ),
                                                                                  ),
                                                                                ]);
                                                                          });
                                                                })
                                                              : Column(
                                                                  children: [
                                                                    const EmptyImage(
                                                                      align: Alignment.center,
                                                                    ),
                                                                    ButtonLink(
                                                                      AppLocalizations.of(
                                                                              context)
                                                                          .translate(i18
                                                                              .attendanceMgmt
                                                                              .addNewWageSeeker),
                                                                      () {},
                                                                      align: Alignment.center,
                                                                    ),
                                                                  ],
                                                                ),
                                                              const Align(
                                                                alignment: Alignment.bottomCenter,
                                                                child: PoweredByDigit(),
                                                              )
                                                        ]))
                                                  ]),
                                                ),
                                                individualMusterRollModel?.musterRoll?.first
                                                                .individualEntries !=
                                                            null &&
                                                        individualMusterRollModel
                                                            !.musterRoll!
                                                            .first
                                                            .individualEntries!
                                                            .isNotEmpty
                                                    ? Align(
                                                        alignment: Alignment.bottomCenter,
                                                        child: Padding(
                                                          padding: const EdgeInsets.only(
                                                            left: 8.0,
                                                            right: 8.0,
                                                          ),
                                                          child: BlocListener<MusterGetWorkflowBloc, MusterGetWorkflowState>(
                                                            listener: (context, workflowState) {
                                                              workflowState.maybeWhen(
                                                                  loading: () => shg_loader.Loaders.circularLoader(context),
                                                                  error: () {
                                                                    Notifiers.getToastMessage(
                                                                        context,
                                                                        AppLocalizations.of(
                                                                                context)
                                                                            .translate(i18
                                                                                .attendanceMgmt
                                                                                .unableToCheckWorkflowStatus),
                                                                        'ERROR');
                                                                  },
                                                                  loaded: (MusterWorkFlowModel? musterWorkFlowModel, bool isInWorkFlow) {
                                                                    if (!isInWorkFlow) {
                                                                      if(inWorkFlow != false){
                                                                        setState(() {
                                                                          inWorkFlow = false;
                                                                        });
                                                                      }
                                                                    } else {
                                                                      if (individualMusterRollModel
                                                                          .musterRoll!
                                                                          .isNotEmpty) {
                                                                        if(inWorkFlow != true) {
                                                                          setState(() {
                                                                            inWorkFlow = true;
                                                                          });
                                                                        }
                                                                      }
                                                                    }
                                                                  },
                                                                  orElse: () =>
                                                                      Container());
                                                            },
                                                            child: BlocBuilder<
                                                                    MusterGetWorkflowBloc,
                                                                    MusterGetWorkflowState>(
                                                                builder: (context,
                                                                    workFlowState) {
                                                                  return workFlowState.maybeWhen(orElse: () => Container(),
                                                                      error: () => Notifiers.getToastMessage(context, AppLocalizations.of(context).translate(i18.attendanceMgmt.unableToCheckWorkflowStatus), 'ERROR'),
                                                                      loading: () => shg_loader.Loaders.circularLoader(context),
                                                                      loaded: (MusterWorkFlowModel? musterWorkFlowModel, bool inWorkFlow) => inWorkFlow ? Container() : SizedBox(
                                                                        height: 100,
                                                                        child: Column(
                                                                children: [
                                                                  BlocListener<
                                                                        AttendanceLogCreateBloc,
                                                                        AttendanceLogCreateState>(
                                                                    listener: (context,
                                                                          logState) {
                                                                        SchedulerBinding
                                                                            .instance
                                                                            .addPostFrameCallback(
                                                                                (_) {
                                                                          logState.maybeWhen(
                                                                              error: (String? error) {
                                                                                if (!hasLoaded) {
                                                                                  Notifiers.getToastMessage(
                                                                                      context,
                                                                                      AppLocalizations.of(context).translate(error.toString()),
                                                                                      'ERROR');
                                                                                  onSubmit(
                                                                                      registerId
                                                                                          .toString());
                                                                                  hasLoaded =
                                                                                      true;
                                                                                }
                                                                              },
                                                                              loaded: () {
                                                                                if (!hasLoaded) {
                                                                                  Notifiers.getToastMessage(
                                                                                      context,
                                                                                      AppLocalizations.of(context).translate(i18
                                                                                          .attendanceMgmt
                                                                                          .attendanceLoggedSuccess),
                                                                                      'SUCCESS');
                                                                                  onSubmit(
                                                                                      registerId
                                                                                          .toString());
                                                                                  hasLoaded =
                                                                                      true;
                                                                                }
                                                                              },
                                                                              orElse: () =>
                                                                                  Container());
                                                                        });
                                                                    },
                                                                    child: OutlinedButton(
                                                                          style: OutlinedButton.styleFrom(
                                                                              backgroundColor:
                                                                                  Colors
                                                                                      .white,
                                                                              side: BorderSide(
                                                                                  width: 2,
                                                                                  color:(createAttendeePayload.isEmpty && updateAttendeePayload.isEmpty) ? const Color.fromRGBO(149, 148, 148, 1) : DigitTheme
                                                                                      .instance
                                                                                      .colorScheme
                                                                                      .secondary)),
                                                                          onPressed: inWorkFlow || (updateAttendeePayload.isEmpty && createAttendeePayload.isEmpty) ? null : () {
                                                                            if (selectedDateRange ==
                                                                                null) {
                                                                              Notifiers.getToastMessage(
                                                                                  context,
                                                                                  AppLocalizations.of(
                                                                                          context)
                                                                                      .translate(i18
                                                                                          .attendanceMgmt
                                                                                          .selectDateRangeFirst),
                                                                                  'ERROR');
                                                                            } else {
                                                                              hasLoaded =
                                                                                  false;
                                                                              if (updateAttendeePayload
                                                                                      .isNotEmpty &&
                                                                                  createAttendeePayload
                                                                                      .isNotEmpty) {
                                                                                context
                                                                                    .read<
                                                                                        AttendanceLogCreateBloc>()
                                                                                    .add(UpdateAttendanceLogEvent(
                                                                                        attendanceList:
                                                                                            updateAttendeePayload));
                                                                                context
                                                                                    .read<
                                                                                        AttendanceLogCreateBloc>()
                                                                                    .add(CreateAttendanceLogEvent(
                                                                                        attendanceList:
                                                                                            createAttendeePayload));
                                                                              } else if (updateAttendeePayload
                                                                                  .isNotEmpty) {
                                                                                context
                                                                                    .read<
                                                                                        AttendanceLogCreateBloc>()
                                                                                    .add(UpdateAttendanceLogEvent(
                                                                                        attendanceList:
                                                                                            updateAttendeePayload));
                                                                              } else if (createAttendeePayload
                                                                                  .isNotEmpty) {
                                                                                context
                                                                                    .read<
                                                                                        AttendanceLogCreateBloc>()
                                                                                    .add(CreateAttendanceLogEvent(
                                                                                        attendanceList:
                                                                                            createAttendeePayload));
                                                                              }
                                                                            }
                                                                          },
                                                                          child: Center(
                                                                              child: Text(
                                                                            AppLocalizations.of(
                                                                                    context)
                                                                                .translate(i18
                                                                                    .common
                                                                                    .saveAsDraft),
                                                                            style: (createAttendeePayload.isEmpty && updateAttendeePayload.isEmpty)
                                                                                ? DigitTheme.instance.mobileTheme.textTheme.bodyLarge?.apply(color: const Color.fromRGBO(149, 148, 148, 1))
                                                                                : DigitTheme.instance.mobileTheme.textTheme.bodyLarge?.apply(color: const DigitColors().burningOrange),
                                                                          ))),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 10,
                                                                  ),
                                                                  BlocListener<
                                                                            MusterCreateBloc,
                                                                            MusterCreateState>(
                                                                        listener: (context,
                                                                            musterUpdateState) {
                                                                            musterUpdateState
                                                                                .maybeWhen(
                                                                                    error:
                                                                                        () {
                                                                                        Notifiers.getToastMessage(
                                                                                            context,
                                                                                            AppLocalizations.of(context).translate(i18.attendanceMgmt.musterUpdateFailed),
                                                                                            'ERROR');
                                                                                        context.router.popAndPush(SHGInboxRoute(tenantId: widget.tenantId, musterRollNo: widget.musterRollNo, sentBackCode: widget.sentBackCode));
                                                                                    },
                                                                                    loaded: (MusterRollsModel?
                                                                                        createdMuster) {
                                                                                        Notifiers.getToastMessage(
                                                                                            context,
                                                                                            '${createdMuster?.musterRoll?.first.musterRollNumber} ${AppLocalizations.of(context).translate(i18.attendanceMgmt.musterSentForApproval)}',
                                                                                            'SUCCESS');
                                                                                        updateLoaded =
                                                                                            true;
                                                                                        context.router.popAndPush(SHGInboxRoute(tenantId: widget.tenantId, musterRollNo: widget.musterRollNo, sentBackCode: widget.sentBackCode));

                                                                                    },
                                                                                    orElse: () =>
                                                                                        false);
                                                                        },
                                                                        child:
                                                                            DigitElevatedButton(
                                                                          onPressed:!inWorkFlow
                                                                                  ? () {
                                                                                      if (selectedDateRange ==
                                                                                          null) {
                                                                                        Notifiers.getToastMessage(
                                                                                            context,
                                                                                            AppLocalizations.of(context).translate(i18.attendanceMgmt.selectDateRangeFirst),
                                                                                            'ERROR');
                                                                                      }
                                                                                      else if (updateAttendeePayload.isNotEmpty || createAttendeePayload.isNotEmpty) {
                                                                                        Notifiers.getToastMessage(context, AppLocalizations.of(context).translate(i18.attendanceMgmt.attendanceChangedValidation), 'INFO');
                                                                                      }
                                                                                      else if (newList.any((e) =>
                                                                                              e.skill == null ||
                                                                                              e.skill.toString().isEmpty)) {
                                                                                        Notifiers.getToastMessage(
                                                                                            context,
                                                                                            AppLocalizations.of(context).translate(i18.attendanceMgmt.reviewSkills),
                                                                                            'INFO');
                                                                                      } else {
                                                                                        updateLoaded =
                                                                                            false;
                                                                                        context.read<MusterCreateBloc>().add(UpdateMusterEvent(
                                                                                            tenantId: widget.tenantId,
                                                                                            id: musterId.toString(),
                                                                                            reSubmitAction: musterWorkFlowModel?.processInstances?.first.nextActions?.first.action,
                                                                                            contractId: individualMusterRollModel.musterRoll!.first.musterAdditionalDetails!.contractId ?? 'NA',
                                                                                            registerNo: individualMusterRollModel.musterRoll!.first.musterAdditionalDetails!.attendanceRegisterNo ?? 'NA',
                                                                                            registerName: individualMusterRollModel.musterRoll!.first.musterAdditionalDetails!.attendanceRegisterName ?? 'NA',
                                                                                            orgName: individualMusterRollModel.musterRoll!.first.musterAdditionalDetails!.contractId ?? 'NA',
                                                                                            skillsList: skillsPayLoad));
                                                                                      }
                                                                                    }
                                                                                  : null,
                                                                          child: Text(
                                                                              AppLocalizations.of(
                                                                                      context)
                                                                                  .translate(i18
                                                                                      .attendanceMgmt
                                                                                      .resubmitMusterRoll),
                                                                              style: DigitTheme.instance.mobileTheme.textTheme.bodyLarge?.apply(color: Colors.white)),
                                                                        )),
                                                                ],
                                                              ),
                                                                      ));
                                                                  }),
                                                          ),
                                                        ),
                                                      )
                                                    : Container()
                                              ]);
                                            });
                                      })
                                  ));
                                }
                              );
                            });
                      });
                    });
              }));
        }
      ),
    );
  }

  void onTextSearch() {
    if (searchController.text.isNotEmpty) {
      setState(() {
        newList.retainWhere((e) =>
            e.name!.toLowerCase().contains(searchController.text.toLowerCase()));
      });
    } else {
      onSubmit(registerId.toString());
    }
  }

  void onSubmit(String registerId) {
    if (selectedDateRange != null) {
      newList.clear();
      updateAttendeePayload.clear();
      createAttendeePayload.clear();
      context.read<MusterRollEstimateBloc>().add(
            ViewEstimateMusterRollEvent(
              tenantId: widget.tenantId,
              registerId: registerId.toString(),
              startDate: selectedDateRange!.startDate,
              endDate: selectedDateRange!.endDate,
            ),
          );
      context.read<MusterGetWorkflowBloc>().add(
            GetMusterWorkflowEvent(
                tenantId: widget.tenantId,
                musterRollNumber: widget.musterRollNo,
            musterSentBackCode: widget.sentBackCode),
          );
    } else {
      Notifiers.getToastMessage(
          context,
          AppLocalizations.of(context)
              .translate(i18.attendanceMgmt.selectDateRangeFirst),
          'ERROR');
    }
  }

  List<TableHeader> get headerList => [
        TableHeader(
          AppLocalizations.of(scaffoldMessengerKey.currentContext!)
              .translate(i18.common.nameLabel),
          apiKey: 'name',
        ),
    TableHeader(
      AppLocalizations.of(scaffoldMessengerKey.currentContext!)
          .translate(i18.common.fatherName),
      apiKey: 'individualGaurdianName',
    ),
    TableHeader(
      '${AppLocalizations.of(scaffoldMessengerKey.currentContext!)
          .translate(i18.attendanceMgmt.skill)}*',
      hide: false
        ),
        TableHeader(
          AppLocalizations.of(scaffoldMessengerKey.currentContext!)
              .translate(i18.common.mon),
            subLabel: dates.isNotEmpty ? dates[0] : ''
        ),
        TableHeader(
          AppLocalizations.of(scaffoldMessengerKey.currentContext!)
              .translate(i18.common.tue),
            subLabel: dates.isNotEmpty ? dates[1] : ''
        ),
        TableHeader(
          AppLocalizations.of(scaffoldMessengerKey.currentContext!)
              .translate(i18.common.wed),
            subLabel: dates.isNotEmpty ? dates[2] : ''
        ),
        TableHeader(
          AppLocalizations.of(scaffoldMessengerKey.currentContext!)
              .translate(i18.common.thu),
            subLabel: dates.isNotEmpty ? dates[3] : ''
        ),
        TableHeader(
          AppLocalizations.of(scaffoldMessengerKey.currentContext!)
              .translate(i18.common.fri),
            subLabel: dates.isNotEmpty ? dates[4] : ''
        ),
        TableHeader(
          AppLocalizations.of(scaffoldMessengerKey.currentContext!)
              .translate(i18.common.sat),
            subLabel: dates.isNotEmpty ? dates[5] : ''
        ),
        TableHeader(
          AppLocalizations.of(scaffoldMessengerKey.currentContext!)
              .translate(i18.common.sun),
            subLabel: dates.isNotEmpty ? dates[6] : ''
        ),
        TableHeader(
          AppLocalizations.of(scaffoldMessengerKey.currentContext!)
              .translate(i18.common.total),
        )
      ];

  TableDataRow getAttendanceRow(TrackAttendanceTableData tableDataModel) {
    return TableDataRow([
      TableData(label: tableDataModel.name, apiKey: tableDataModel.name),
      TableData(label: tableDataModel.individualGaurdianName, apiKey: tableDataModel.individualGaurdianName),
      TableData(
          apiKey: tableDataModel.skill,
          hide: false,
          widget: DropDownDialog(
            isDisabled: inWorkFlow || (tableDataModel.skillCodeList ?? []).isEmpty,
            options: tableDataModel.skillCodeList ?? [],
            label: i18.common.selectSkill,
            selectedOption: tableDataModel.skill.toString(),
            onChanged: (val) {
              tableDataModel.skill = val;
              if (skillsPayLoad
                  .where(
                      (e) => e["individualId"] == tableDataModel.individualId)
                  .isNotEmpty) {
                skillsPayLoad.removeWhere((elem) =>
                    elem["individualId"] == tableDataModel.individualId);
                // if(tableDataModel.id != null && tableDataModel.id!.trim().isNotEmpty) {
                //   skillsPayLoad.add({
                //     "id": tableDataModel.id,
                //     "additionalDetails": {
                //       "code": val
                //     }
                //   });
                // }
                // else {
                  skillsPayLoad.add({
                    "individualId": tableDataModel.individualId,
                    "additionalDetails": {
                      "code": val
                    }
                  });
                // }
              } else {
                // if(tableDataModel.id != null && tableDataModel.id!.trim().isNotEmpty) {
                //   skillsPayLoad.add({
                //     "id": tableDataModel.id,
                //     "additionalDetails": {
                //       "code": val
                //     }
                //   });
                // }
                // else {
                  skillsPayLoad.add({
                    "individualId": tableDataModel.individualId,
                    "additionalDetails": {
                      "code": val
                    }
                  });
                // }
              }
            },
          )),
      TableData(
        apiKey: tableDataModel.monIndex.toString(),
        widget: CircularButton(
          icon: Icons.circle_rounded,
          size: 15,
          viewOnly: inWorkFlow,
          color: const Color.fromRGBO(0, 100, 0, 1),
          index: tableDataModel.monIndex ?? 0.0,
          isNotGreyed: false,
          onTap: (daysInRange == null || !daysInRange!.monday) && inWorkFlow
              ? null
              : entryExitList!.length > 2
                  ? () => onTapButton(
                      tableDataModel.individualId ?? '',
                      'mon',
                      tableDataModel.monEntryId,
                      tableDataModel.monExitId,
                      tableDataModel.auditDetails)
                  : () => onTapOnlyAbsentPresent(
                      tableDataModel.individualId ?? '',
                      'mon',
                      tableDataModel.monEntryId,
                      tableDataModel.monExitId,
                      tableDataModel.auditDetails),
        ),
      ),
      TableData(
          widget: CircularButton(
        icon: Icons.circle_rounded,
        size: 15,
            viewOnly: inWorkFlow,
        color: const Color.fromRGBO(0, 100, 0, 1),
        index: tableDataModel.tueIndex ?? 0,
        isNotGreyed: false,
        onTap:( daysInRange == null || !daysInRange!.tuesday) && inWorkFlow
            ? null
            : entryExitList!.length > 2
                ? () => onTapButton(
                    tableDataModel.individualId ?? '',
                    'tue',
                    tableDataModel.tueEntryId,
                    tableDataModel.tueExitId,
                    tableDataModel.auditDetails)
                : () => onTapOnlyAbsentPresent(
                    tableDataModel.individualId ?? '',
                    'tue',
                    tableDataModel.tueEntryId,
                    tableDataModel.tueExitId,
                    tableDataModel.auditDetails),
      )),
      TableData(
          widget: CircularButton(
        icon: Icons.circle_rounded,
            viewOnly: inWorkFlow,
        size: 15,
        color: const Color.fromRGBO(0, 100, 0, 1),
        index: tableDataModel.wedIndex ?? 0,
        isNotGreyed: false,
        onTap: (daysInRange == null || !daysInRange!.wednesday) && inWorkFlow
            ? null
            : entryExitList!.length > 2
                ? () => onTapButton(
                    tableDataModel.individualId ?? '',
                    'wed',
                    tableDataModel.wedEntryId,
                    tableDataModel.wedExitId,
                    tableDataModel.auditDetails)
                : () => onTapOnlyAbsentPresent(
                    tableDataModel.individualId ?? '',
                    'wed',
                    tableDataModel.wedEntryId,
                    tableDataModel.wedExitId,
                    tableDataModel.auditDetails),
      )),
      TableData(
          widget: CircularButton(
        icon: Icons.circle_rounded,
        size: 15,
            viewOnly: inWorkFlow,
        color: const Color.fromRGBO(0, 100, 0, 1),
        index: tableDataModel.thuIndex ?? 0,
        isNotGreyed: false,
        onTap: (daysInRange == null || !daysInRange!.thursday) && inWorkFlow
            ? null
            : entryExitList!.length > 2
                ? () => onTapButton(
                    tableDataModel.individualId ?? '',
                    'thu',
                    tableDataModel.thuEntryId,
                    tableDataModel.thuExitId,
                    tableDataModel.auditDetails)
                : () => onTapOnlyAbsentPresent(
                    tableDataModel.individualId ?? '',
                    'thu',
                    tableDataModel.thuEntryId,
                    tableDataModel.thuExitId,
                    tableDataModel.auditDetails),
      )),
      TableData(
          widget: CircularButton(
        icon: Icons.circle_rounded,
        size: 15,
            viewOnly: inWorkFlow,
        color: const Color.fromRGBO(0, 100, 0, 1),
        index: tableDataModel.friIndex ?? 0,
        isNotGreyed: false,
        onTap: (daysInRange == null || !daysInRange!.friday) && inWorkFlow
            ? null
            : entryExitList!.length > 2
                ? () => onTapButton(
                    tableDataModel.individualId ?? '',
                    'fri',
                    tableDataModel.friEntryId,
                    tableDataModel.friExitId,
                    tableDataModel.auditDetails)
                : () => onTapOnlyAbsentPresent(
                    tableDataModel.individualId ?? '',
                    'fri',
                    tableDataModel.friEntryId,
                    tableDataModel.friExitId,
                    tableDataModel.auditDetails),
      )),
      TableData(
          widget: CircularButton(
        icon: Icons.circle_rounded,
        size: 15,
            viewOnly: inWorkFlow,
        color: const Color.fromRGBO(0, 100, 0, 1),
        index: tableDataModel.satIndex ?? 0,
        isNotGreyed: false,
        onTap: (daysInRange == null || !daysInRange!.saturday) && inWorkFlow
            ? null
            : entryExitList!.length > 2
                ? () => onTapButton(
                    tableDataModel.individualId ?? '',
                    'sat',
                    tableDataModel.satEntryId,
                    tableDataModel.satExitId,
                    tableDataModel.auditDetails)
                : () => onTapOnlyAbsentPresent(
                    tableDataModel.individualId ?? '',
                    'sat',
                    tableDataModel.satEntryId,
                    tableDataModel.satExitId,
                    tableDataModel.auditDetails),
      )),
      TableData(
          widget: CircularButton(
        icon: Icons.circle_rounded,
        size: 15,
            viewOnly: inWorkFlow,
        color: const Color.fromRGBO(0, 100, 0, 1),
        index: tableDataModel.sunIndex ?? 0,
        isNotGreyed: false,
        onTap: (daysInRange == null || !daysInRange!.sunday) && inWorkFlow
            ? null
            : entryExitList!.length > 2
                ? () => onTapButton(
                    tableDataModel.individualId ?? '',
                    'sun',
                    tableDataModel.sunEntryId,
                    tableDataModel.sunExitId,
                    tableDataModel.auditDetails)
                : () => onTapOnlyAbsentPresent(
                    tableDataModel.individualId ?? '',
                    'sun',
                    tableDataModel.sunEntryId,
                    tableDataModel.sunExitId,
                    tableDataModel.auditDetails),
      )),
      TableData(label: (convertedValue(tableDataModel.monIndex!.toDouble()) + convertedValue(tableDataModel.tueIndex!.toDouble())
          + convertedValue(tableDataModel.wedIndex!.toDouble()) + convertedValue(tableDataModel.thuIndex!.toDouble())
          + convertedValue(tableDataModel.friIndex!.toDouble()) + convertedValue(tableDataModel.satIndex!.toDouble())
          + convertedValue(tableDataModel.sunIndex!.toDouble())).toString(),)
    ]);
  }

  List<TableDataRow> getAttendanceData(List<TrackAttendanceTableData> list) {
    return list.map((e) => getAttendanceRow(e)).toList();
  }
  double convertedValue(double tableVal){
    if(tableVal < 0){
      return 0;
    }
    else{
      return tableVal;
    }
  }

  void onTapButton(individualId, day, entryID, exitId, auditDetails) {
    int morning =
        entryExitList?.firstWhere((e) => e.code == 'MORNING').hours ?? 0;
    int afternoon =
        entryExitList?.firstWhere((e) => e.code == 'AFTERNOON').hours ?? 0;
    int evening =
        entryExitList?.firstWhere((e) => e.code == 'EVENING').hours ?? 0;
    int index = newList.indexWhere((item) => item.individualId == individualId);

    if (index != -1) {
      setState(() {
        if (newList[index].getProperty(day) == 0.0 ||
            newList[index].getProperty(day) == -1) {
          newList[index].setProperty(day, 1.0);
          if (entryID != null && exitId != null) {
            updateAttendeePayload.removeWhere((e) =>
            e['individualId'] == individualId &&
                DateFormats.getDay(e['time']).toLowerCase() == day);
            updateAttendeePayload.addAll(updateAttendanceLogPayload(
                newList[index],
                registerId ?? '',
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    evening),
                entryID,
                exitId,
                widget.tenantId,
                auditDetails,
                true,
                true));
          } else {
            createAttendeePayload.removeWhere((e) =>
            e['individualId'] == individualId &&
                DateFormats.getDay(e['time']).toLowerCase() == day);
            createAttendeePayload.addAll(createAttendanceLogPayload(
                newList[index],
                registerId ?? '',
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    evening),
                widget.tenantId));
          }
        } else if (newList[index].getProperty(day) == 0.5) {
          newList[index].setProperty(day, 0.0);
          if (entryID != null && exitId != null) {
            updateAttendeePayload.removeWhere((e) =>
            e['individualId'] == individualId &&
                DateFormats.getDay(e['time']).toLowerCase() == day);
            updateAttendeePayload.addAll(updateAttendanceLogPayload(
                newList[index],
                registerId ?? '',
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                entryID,
                exitId,
                widget.tenantId,
                auditDetails,
                false,
                false));
          } else {
            createAttendeePayload.removeWhere((e) =>
            e['individualId'] == individualId &&
                DateFormats.getDay(e['time']).toLowerCase() == day);
          }
        } else {
          newList[index].setProperty(day, 0.5);
          if (entryID != null && exitId != null) {
            updateAttendeePayload.removeWhere((e) =>
            e['individualId'] == individualId &&
                DateFormats.getDay(e['time']).toLowerCase() == day);
            updateAttendeePayload.addAll(updateAttendanceLogPayload(
                newList[index],
                registerId ?? '',
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    afternoon),
                entryID,
                exitId,
                widget.tenantId,
                auditDetails,
                true,
                true));
          } else {
            createAttendeePayload.removeWhere((e) =>
            e['individualId'] == individualId &&
                DateFormats.getDay(e['time']).toLowerCase() == day);
            createAttendeePayload.addAll(createAttendanceLogPayload(
                newList[index],
                registerId ?? '',
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    afternoon),
                widget.tenantId));
          }
        }
      });
    }
    else{}
    if(newList.any((e) => e.monIndex == -1 && e.tueIndex == -1 && e.wedIndex == -1 && e.thuIndex == -1 && e.friIndex == -1 && e.satIndex == -1 && e.sunIndex == -1)) {
      setState(() {
        for (var n in newList) {
          if (n.monIndex == -1 && n.tueIndex == -1 && n.wedIndex == -1 &&
              n.thuIndex == -1 && n.friIndex == -1 && n.satIndex == -1 &&
              n.sunIndex == -1) {
            createAttendeePayload.addAll(createAttendanceLogPayload(n,
                registerId ?? '',
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                widget.tenantId));
          }
        };
      });
    }
  }

  void onTapOnlyAbsentPresent(
      individualId, day, entryID, exitId, auditDetails) {
    int morning =
        entryExitList?.firstWhere((e) => e.code == 'MORNING').hours ?? 0;
    int evening =
        entryExitList?.firstWhere((e) => e.code == 'EVENING').hours ?? 0;
    int index = newList.indexWhere((item) => item.individualId == individualId);

    if (index != -1) {
      setState(() {
        if (newList[index].getProperty(day) == 0.0 ||
            newList[index].getProperty(day) == -1) {
          newList[index].setProperty(day, 0.0);
          if (entryID != null && exitId != null) {
            updateAttendeePayload.removeWhere((e) =>
            e['individualId'] == individualId &&
                DateFormats.getDay(e['time']).toLowerCase() == day);
            updateAttendeePayload.addAll(updateAttendanceLogPayload(
                newList[index],
                registerId ?? '',
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                entryID,
                exitId,
                widget.tenantId,
                auditDetails,
                false,
                false));
          } else {
            createAttendeePayload.removeWhere((e) =>
            e['individualId'] == individualId &&
                DateFormats.getDay(e['time']).toLowerCase() == day);
          }
        } else {
          newList[index].setProperty(day, 1.0);
          if (entryID != null && exitId != null) {
            updateAttendeePayload.removeWhere((e) =>
            e['individualId'] == individualId &&
                DateFormats.getDay(e['time']).toLowerCase() == day);
            updateAttendeePayload.addAll(updateAttendanceLogPayload(
                newList[index],
                registerId ?? '',
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    evening),
                entryID,
                exitId,
                widget.tenantId,
                auditDetails,
                true,
                true));
          } else {
            createAttendeePayload.removeWhere((e) =>
            e['individualId'] == individualId &&
                DateFormats.getDay(e['time']).toLowerCase() == day);
            createAttendeePayload.addAll(createAttendanceLogPayload(
                newList[index],
                registerId ?? '',
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    evening),
                widget.tenantId));
          }
        }
      });
    }
    else{}
    if(newList.any((e) => e.monIndex == -1 && e.tueIndex == -1 && e.wedIndex == -1 && e.thuIndex == -1 && e.friIndex == -1 && e.satIndex == -1 && e.sunIndex == -1)) {
      setState(() {
        for (var n in newList) {
          if (n.monIndex == -1 && n.tueIndex == -1 && n.wedIndex == -1 &&
              n.thuIndex == -1 && n.friIndex == -1 && n.satIndex == -1 &&
              n.sunIndex == -1) {
            createAttendeePayload.addAll(createAttendanceLogPayload(n,
                registerId ?? '',
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                DateFormats.getTimestampFromWeekDay(
                    DateFormats.getDateFromTimestamp(
                        selectedDateRange!.startDate),
                    day,
                    morning),
                widget.tenantId));
          }
        };
      });
    }
  }
}
