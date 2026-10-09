import 'package:flutter/material.dart';
import '../../core/repositories/admin_modules_repository.dart';
import '../../core/repositories/catalog_repository.dart';
import 'generic_crud_screen.dart';

class AdminTestimonialsScreen extends StatelessWidget {
  const AdminTestimonialsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return GenericCrudScreen(
      title: 'آراء الطلاب',
      fields: const [
        CrudField('studentName', 'اسم الطالب', required: true),
        CrudField('destination', 'الوجهة الدراسية'),
        CrudField('quote', 'الرأي', type: CrudFieldType.multiline, required: true),
        CrudField('avatar', 'الصورة الشخصية', type: CrudFieldType.image),
        CrudField('rating', 'التقييم (1-5)', type: CrudFieldType.number),
        CrudField('featured', 'مميز؟', type: CrudFieldType.boolean),
      ],
      imageUploadPaths: const {'avatar': '/admin/testimonials/upload-avatar'},
      fetchItems: repo.getTestimonials,
      createItem: repo.createTestimonial,
      updateItem: repo.updateTestimonial,
      deleteItem: repo.deleteTestimonial,
      itemTitle: (i) => i['studentName'] as String? ?? '—',
      itemSubtitle: (i) => i['quote'] as String? ?? '',
    );
  }
}

class AdminRecognitionsScreen extends StatelessWidget {
  const AdminRecognitionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return GenericCrudScreen(
      title: 'الاعتمادات',
      fields: const [
        CrudField('title', 'العنوان', required: true),
        CrudField('detailBody', 'التفاصيل', type: CrudFieldType.multiline),
        CrudField('image', 'الصورة', type: CrudFieldType.image),
        CrudField('link', 'رابط خارجي (اختياري)'),
        CrudField('featured', 'مميز؟', type: CrudFieldType.boolean),
      ],
      imageUploadPaths: const {'image': '/admin/recognitions/upload-image'},
      fetchItems: repo.getRecognitions,
      createItem: repo.createRecognition,
      updateItem: repo.updateRecognition,
      deleteItem: repo.deleteRecognition,
      itemTitle: (i) => i['title'] as String? ?? '—',
      itemSubtitle: (i) => i['detailBody'] as String? ?? '',
    );
  }
}

class AdminServicesScreen extends StatelessWidget {
  const AdminServicesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return GenericCrudScreen(
      title: 'الخدمات',
      fields: const [
        CrudField('title', 'العنوان', required: true),
        CrudField('detailBody', 'الوصف', type: CrudFieldType.multiline),
        CrudField('priceDescription', 'السعر والعملة أو شروط التسعير'),
        CrudField('estimatedDuration', 'الوقت التقديري للتنفيذ'),
        CrudField('requirementsText', 'متطلبات التقديم', type: CrudFieldType.multiline),
        CrudField('documentsText', 'المستندات اللازمة', type: CrudFieldType.multiline),
        CrudField('image', 'الصورة', type: CrudFieldType.image),
        CrudField('featured', 'مميز؟', type: CrudFieldType.boolean),
      ],
      imageUploadPaths: const {'image': '/admin/our-services/upload-image'},
      fetchItems: repo.getServices,
      createItem: repo.createService,
      updateItem: repo.updateService,
      deleteItem: repo.deleteService,
      itemTitle: (i) => i['title'] as String? ?? '—',
      itemSubtitle: (i) => i['detailBody'] as String? ?? '',
    );
  }
}

class AdminFaqsScreen extends StatelessWidget {
  const AdminFaqsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return GenericCrudScreen(
      title: 'الأسئلة الشائعة',
      fields: const [
        CrudField('question', 'السؤال', required: true),
        CrudField('answer', 'الإجابة', type: CrudFieldType.multiline, required: true),
        CrudField('featured', 'مميز؟', type: CrudFieldType.boolean),
      ],
      fetchItems: repo.getFaqs,
      createItem: repo.createFaq,
      updateItem: repo.updateFaq,
      deleteItem: repo.deleteFaq,
      itemTitle: (i) => i['question'] as String? ?? '—',
      itemSubtitle: (i) => i['answer'] as String? ?? '',
    );
  }
}

class AdminCountriesScreen extends StatelessWidget {
  const AdminCountriesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return GenericCrudScreen(
      title: 'الدول',
      fields: const [
        CrudField('name', 'اسم الدولة', required: true),
        CrudField('code', 'رمز الدولة (مثال: TR)', required: true),
        CrudField('description', 'الوصف', type: CrudFieldType.multiline),
        CrudField('visaNotes', 'ملاحظات التأشيرة', type: CrudFieldType.multiline),
        CrudField('heroImage', 'صورة الغلاف', type: CrudFieldType.image),
        CrudField('universityCount', 'عدد الجامعات', type: CrudFieldType.number),
        CrudField('specialtyCount', 'عدد التخصصات', type: CrudFieldType.number),
        CrudField('averageTuition', 'متوسط الرسوم', type: CrudFieldType.number),
        CrudField('featured', 'مميزة؟', type: CrudFieldType.boolean),
      ],
      imageUploadPaths: const {'heroImage': '/admin/countries/upload-image'},
      fetchItems: repo.getCountries,
      createItem: repo.createCountry,
      updateItem: repo.updateCountry,
      deleteItem: repo.deleteCountry,
      itemTitle: (i) => i['name'] as String? ?? '—',
      itemSubtitle: (i) => i['description'] as String? ?? '',
    );
  }
}

class AdminStudyFieldsScreen extends StatelessWidget {
  const AdminStudyFieldsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return GenericCrudScreen(
      title: 'المجالات الدراسية',
      fields: const [
        CrudField('name', 'اسم المجال', required: true),
        CrudField('description', 'الوصف', type: CrudFieldType.multiline),
        CrudField('image', 'الصورة', type: CrudFieldType.image),
        CrudField('featured', 'مميز؟', type: CrudFieldType.boolean),
      ],
      imageUploadPaths: const {'image': '/admin/study-fields/upload-image'},
      fetchItems: repo.getStudyFields,
      createItem: repo.createStudyField,
      updateItem: repo.updateStudyField,
      deleteItem: repo.deleteStudyField,
      itemTitle: (i) => i['name'] as String? ?? '—',
      itemSubtitle: (i) => i['description'] as String? ?? '',
    );
  }
}

class AdminUniversitiesCrudScreen extends StatelessWidget {
  const AdminUniversitiesCrudScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return GenericCrudScreen(
      title: 'الجامعات',
      fields: const [
        CrudField('name', 'اسم الجامعة', required: true),
        CrudField('country', 'معرّف الدولة (Country ID)', required: true),
        CrudField('city', 'المدينة'),
        CrudField('language', 'اللغة'),
        CrudField('overview', 'نظرة عامة', type: CrudFieldType.multiline),
        CrudField('logo', 'الشعار', type: CrudFieldType.image),
        CrudField('featured', 'مميزة؟', type: CrudFieldType.boolean),
        CrudField('isPartnerInstitution', 'جامعة شريكة؟', type: CrudFieldType.boolean),
      ],
      imageUploadPaths: const {'logo': '/universities/upload-images'},
      imageFieldNames: const {'logo': 'files'},
      fetchItems: () => CatalogRepository.instance.getUniversities(),
      createItem: repo.createUniversity,
      updateItem: repo.updateUniversity,
      deleteItem: repo.deleteUniversity,
      itemTitle: (i) => i['name'] as String? ?? '—',
      itemSubtitle: (i) => i['city'] as String? ?? '',
    );
  }
}

class AdminProgramsCrudScreen extends StatelessWidget {
  const AdminProgramsCrudScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return GenericCrudScreen(
      title: 'البرامج',
      fields: const [
        CrudField('title', 'اسم البرنامج', required: true),
        CrudField('university', 'معرّف الجامعة (University ID)', required: true),
        CrudField('degreeLevel', 'الدرجة العلمية', required: true),
        CrudField('fieldOfStudy', 'مجال الدراسة', required: true),
        CrudField('language', 'لغة الدراسة'),
        CrudField('duration', 'مدة الدراسة'),
        CrudField('tuition', 'الرسوم', type: CrudFieldType.number),
        CrudField('intake', 'الفصل الدراسي'),
        CrudField('summary', 'ملخص', type: CrudFieldType.multiline),
      ],
      fetchItems: () => CatalogRepository.instance.getPrograms(),
      createItem: repo.createProgram,
      updateItem: repo.updateProgram,
      deleteItem: repo.deleteProgram,
      itemTitle: (i) => i['title'] as String? ?? '—',
      itemSubtitle: (i) => i['degreeLevel'] as String? ?? '',
    );
  }
}

class AdminPastEventsScreen extends StatelessWidget {
  const AdminPastEventsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return GenericCrudScreen(
      title: 'الفعاليات السابقة',
      fields: const [
        CrudField('title', 'العنوان', required: true),
        CrudField('summary', 'الملخص', type: CrudFieldType.multiline),
        CrudField('category', 'الفئة'),
        CrudField('countryCode', 'رمز الدولة'),
        CrudField('coverImage', 'صورة الغلاف', type: CrudFieldType.image),
        CrudField('featured', 'مميزة؟', type: CrudFieldType.boolean),
      ],
      imageUploadPaths: const {'coverImage': '/admin/past-events/upload-media'},
      fetchItems: repo.getPastEvents,
      createItem: repo.createPastEvent,
      updateItem: repo.updatePastEvent,
      deleteItem: repo.deletePastEvent,
      itemTitle: (i) => i['title'] as String? ?? '—',
      itemSubtitle: (i) => i['summary'] as String? ?? '',
    );
  }
}

class AdminBannersScreen extends StatelessWidget {
  const AdminBannersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return GenericCrudScreen(
      title: 'البنرات',
      fields: const [
        CrudField('title', 'العنوان', required: true),
        CrudField('tag', 'التاج (وسم صغير)'),
        CrudField('subtitle', 'العنوان الفرعي'),
        CrudField('actionLabel', 'نص الزر'),
        CrudField('destination', 'الوجهة (universities / programs / apply / services)'),
        CrudField('imageUrl', 'الصورة', type: CrudFieldType.image),
        CrudField('order', 'الترتيب', type: CrudFieldType.number),
        CrudField('active', 'نشط؟', type: CrudFieldType.boolean),
      ],
      imageUploadPaths: const {'imageUrl': '/admin/banners/upload-image'},
      fetchItems: repo.getBanners,
      createItem: repo.createBanner,
      updateItem: repo.updateBanner,
      deleteItem: repo.deleteBanner,
      itemTitle: (i) => i['title'] as String? ?? '—',
      itemSubtitle: (i) => i['subtitle'] as String? ?? '',
    );
  }
}

class AdminExhibitionsScreen extends StatelessWidget {
  const AdminExhibitionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return GenericCrudScreen(
      title: 'محطة المعارض',
      fields: const [
        CrudField('title', 'العنوان', required: true),
        CrudField('summary', 'الملخص', type: CrudFieldType.multiline),
        CrudField('body', 'المحتوى', type: CrudFieldType.multiline, required: true),
        CrudField('image', 'الصورة', type: CrudFieldType.image),
        CrudField('youtubeUrl', 'رابط يوتيوب (اختياري)'),
        CrudField('featured', 'مميز؟', type: CrudFieldType.boolean),
        CrudField('published', 'منشور؟', type: CrudFieldType.boolean),
      ],
      imageUploadPaths: const {'image': '/admin/exhibitions/upload-image'},
      fetchItems: repo.getExhibitions,
      createItem: repo.createExhibition,
      updateItem: repo.updateExhibition,
      deleteItem: repo.deleteExhibition,
      itemTitle: (i) => i['title'] as String? ?? '—',
      itemSubtitle: (i) => i['summary'] as String? ?? '',
    );
  }
}
